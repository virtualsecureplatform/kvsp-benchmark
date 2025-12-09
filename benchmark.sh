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
    echo "       $0 bottleneck [pearl|ruby] [-g NGPUS]"
    exit 1
}

[ $# -lt 1 ] && print_usage_and_exit

KVSP_VER=34

# Download kvsp if not exists
if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
    # Try new naming convention first (kvsp_vNN.tar.gz), then fall back to old (kvsp.tar.gz)
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp_v$KVSP_VER.tar.gz | \
    tar zx || \
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp.tar.gz | \
    tar zx
fi
# Download faststat if not exists
if [ ! -f faststat ]; then
    curl -o faststat -L https://github.com/ushitora-anqou/faststat/releases/download/v0.0.2/faststat
    chmod +x faststat
fi

# Kill all children at exit
# Thanks to: https://stackoverflow.com/a/2173421
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

case "$1" in
    speed-1KiB )
        shift

        KVSP_VER=10001
        if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
            curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v29/kvsp_1KiB.tar.gz |\
            tar zx
            mv kvsp_v29_1KiB "kvsp_v$KVSP_VER"
        fi

        # Prepare Ruby gems
        bundle install || ( echo "Please install bundler. For example: 'gem install bundler'" && false )

        # Make directory for results
        results_dir=$(date +'speed-1KiB-%Y%m%d%H%M%S')
        mkdir $results_dir

        # Log useful information about run
        #sudo ./getlinuxinfo.sh "$results_dir"

        # Run faststat
        faststat_logfile="$results_dir/faststat.log"
        ./faststat -t 0.1 \
            time cpu.user cpu.nice cpu.sys cpu.idle cpu.iowait cpu.irq cpu.softirq \
            cpu.steal mem.total mem.used mem.free mem.shared mem.buff_cache mem.available \
            mem.swap.total mem.swap.used mem.swap.free nvml.temp nvml.power nvml.usage \
            nvml.mem.used nvml.mem.free nvml.mem.total \
            > $faststat_logfile &

        # Run benchmark.rb
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --pearl --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --ruby --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --pearl "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --ruby "$@"

        # Cleanup
        rm _*
        ;;

    speed )
        shift

        # Prepare Ruby gems
        bundle install || ( echo "Please install bundler. For example: 'gem install bundler'" && false )

        # Make directory for results
        results_dir=$(date +'speed-%Y%m%d%H%M%S')
        mkdir $results_dir

        # Log useful information about run
        #sudo ./getlinuxinfo.sh "$results_dir"

        # Run faststat
        faststat_logfile="$results_dir/faststat.log"
        ./faststat -t 0.1 \
            time cpu.user cpu.nice cpu.sys cpu.idle cpu.iowait cpu.irq cpu.softirq \
            cpu.steal mem.total mem.used mem.free mem.shared mem.buff_cache mem.available \
            mem.swap.total mem.swap.used mem.swap.free nvml.temp nvml.power nvml.usage \
            nvml.mem.used nvml.mem.free nvml.mem.total \
            > $faststat_logfile &

        # Run benchmark.rb
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --pearl --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --ruby --cmux-memory "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --pearl "$@"
        bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --output "$results_dir/benchmark_rb.log" --ruby "$@"

        # Cleanup
        rm _*
        ;;

    bottleneck )
        shift

        processor=ruby
        case "$1" in
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

        # Prepare request packet
        kvsp_v$KVSP_VER/bin/kvsp cc 03_bf.c -o _elf
        kvsp_v$KVSP_VER/bin/kvsp genkey -o _sk
        kvsp_v$KVSP_VER/bin/kvsp genbkey -i _sk -o _bk
        kvsp_v$KVSP_VER/bin/kvsp enc -k _sk -i _elf -o _req.packet

        # Prepare KVSP's blueprint. Turn CMUX Memory on.
        bundle exec ruby change_blueprint.rb --cmux-memory "kvsp_v$KVSP_VER/share/kvsp/cahp-$processor.toml"

        # Make directory for results
        results_dir=$(date +'bottleneck-%Y%m%d%H%M%S')
        mkdir $results_dir

        # Log useful information about run
        #sudo ./getlinuxinfo.sh "$results_dir"

        # Run faststat
        faststat_logfile="$results_dir/faststat.log"
        ./faststat -t 0.1 \
            time cpu.user cpu.nice cpu.sys cpu.idle cpu.iowait cpu.irq cpu.softirq \
            cpu.steal nvml.temp nvml.power nvml.usage nvml.mem.used nvml.mem.free \
            nvml.mem.total > $faststat_logfile &

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
