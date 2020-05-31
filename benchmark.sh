#!/bin/bash -eu

### Usage
# $ ./benchmark.sh speed [-g NGPUS]
# $ ./benchmark.sh bottleneck [-g NGPUS]
#
# If you want to send results to Slack,
# $ SLACK_API_TOKEN="xxxxx" SLACK_CHANNEL="#channel" ./benchmark.sh [-g NGPUS]
###

print_usage_and_exit() {
    echo "Usage: $0 speed [-g NGPUS]"
    echo "       $0 bottleneck [emerald|diamond] [-g NGPUS]"
    exit 1
}

[ $# -lt 1 ] && print_usage_and_exit

KVSP_VER=24

# Download kvsp if not exists
if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp.tar.gz | \
    tar zx
fi
# Download faststat if not exists
if [ ! -f faststat ]; then
    curl -o faststat -L https://github.com/ushitora-anqou/faststat/releases/download/v0.0.1/faststat
    chmod +x faststat
fi

case "$1" in
    speed )
        shift

        # Prepare Ruby gems
        bundle install || ( echo "Please install bundler. For example: 'gem install bundler'" && false )

        # Run
        ## Until v21
        #bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar --cmux-memory "$@"
        #bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --cmux-memory "$@"
        #bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER "$@"
        #bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar "$@"
        ## Since v22
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --pearl --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --ruby --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --pearl "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --ruby "$@"

        # Cleanup
        rm _*
        ;;

    bottleneck )
        shift

        processor=pearl
        case "$1" in
            diamond )
                processor=diamond
                shift
                ;;
            emerald)
                processor=emerald
                shift
                ;;
            ruby)
                processor=ruby
                shift
                ;;
            pearl)
                processor=pearl
                shift
                ;;
        esac
        echo "Using processor: $processor"

        # Kill all children at exit
        # Thanks to: https://stackoverflow.com/a/2173421
        trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

        # Prepare request packet
        kvsp_v$KVSP_VER/bin/kvsp cc 03_bf.c -o _elf
        kvsp_v$KVSP_VER/bin/kvsp genkey -o _sk
        kvsp_v$KVSP_VER/bin/kvsp genbkey -i _sk -o _bk
        kvsp_v$KVSP_VER/bin/kvsp enc -k _sk -i _elf -o _req.packet -cahp-cpu $processor

        # Prepare KVSP's blueprint. Turn CMUX Memory on.
        bundle exec ruby change_blueprint.rb --cmux-memory "kvsp_v$KVSP_VER/share/kvsp/cahp-$processor.toml"

        # Make directory for results
        results_dir=$(date +'bottleneck-%Y%m%d%H%M%S')
        mkdir $results_dir

        # Log useful information about run
        sudo ./getlinuxinfo.sh "$results_dir"

        # Run faststat
        faststat_logfile="$results_dir/faststat.log"
        ./faststat -t 0.1 > $faststat_logfile &

        # Run kvsp
        kvsp_logfile="$results_dir/kvsp.log"
        kvsp_logfile2="$results_dir/kvsp-for-dump.log"
        kvsp_time_logfile="$results_dir/kvsp-time"
        kvsp_graph_logfile="$results_dir/kvsp-graph"
        kvsp_v$KVSP_VER/bin/kvsp run -quiet -c 20 -bkey _bk -i _req.packet -o _res.packet \
            -snapshot _snapshot -cahp-cpu $processor \
            -iyokan-args "--stdout-csv" "$@" | tee $kvsp_logfile
        kvsp_v$KVSP_VER/bin/kvsp run -quiet -c 20 -bkey _bk -i _req.packet -o _res.packet \
            -snapshot _snapshot -cahp-cpu $processor \
            -iyokan-args "--stdout-csv" \
            -iyokan-args "--dump-time-csv-prefix=$kvsp_time_logfile" \
            "$@" | tee $kvsp_logfile2

        echo "Results in '$faststat_logfile' and '$kvsp_logfile'"
        ;;

    * )
        print_usage_and_exit
        ;;
esac
