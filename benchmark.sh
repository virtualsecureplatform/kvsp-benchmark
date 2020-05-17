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
    echo "       $0 bottleneck [-g NGPUS]"
    exit 1
}

[ $# -lt 1 ] && print_usage_and_exit

KVSP_VER=18

# Download kvsp if not exist
if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp.tar.gz | \
    tar zx
fi

case "$1" in
    speed )
        shift

        # Prepare Ruby gems
        bundle install || ( echo "Please install bundler. For example: 'gem install bundler'" && false )

        # Run
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar "$@"

        # Cleanup
        rm _*
        ;;

    bottleneck )
        shift

        # Check if faststat is built
        if [ ! -f faststat/build/faststat ]; then
            echo "Build faststat in advance"
            exit 1
        fi

        # Kill all children at exit
        # Thanks to: https://stackoverflow.com/a/2173421
        trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

        # Prepare request packet
        kvsp_v$KVSP_VER/bin/kvsp cc 03_bf.c -o _elf
        kvsp_v$KVSP_VER/bin/kvsp genkey -o _sk
        kvsp_v$KVSP_VER/bin/kvsp enc -k _sk -i _elf -o _req.packet

        # Prepare KVSP's blueprint. Turn CMUX Memory on.
        bundle exec ruby change_blueprint.rb --cmux-memory "kvsp_v$KVSP_VER/share/kvsp/cahp-emerald.toml"

        # Run faststat
        faststat_logfile=$(date +'bottleneck-%Y%m%d%H%M%S-faststat.log')
        faststat/build/faststat -t 0.1 > $faststat_logfile &

        # Run kvsp
        kvsp_logfile=$(date +'bottleneck-%Y%m%d%H%M%S-kvsp.log')
        kvsp_v$KVSP_VER/bin/kvsp run -c 20 -i _req.packet -o _res.packet -iyokan-args "--stdout-csv" "$@" | tee $kvsp_logfile
        ;;

    * )
        print_usage_and_exit
        ;;
esac
