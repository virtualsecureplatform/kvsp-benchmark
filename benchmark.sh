#!/bin/bash -eu

### Usage
# $ ./benchmark.sh [-g NGPUS]
#
# If you want to send results to Slack,
# $ SLACK_API_TOKEN="xxxxx" SLACK_CHANNEL="#channel" ./benchmark.sh [-g NGPUS]
###

KVSP_VER=15

# Download kvsp if not exist
if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp.tar.gz | \
    tar zx
fi

# Prepare Ruby gems
bundle install || ( echo "Please install bundler. For example: 'gem install bundler'" && false )

# Run
bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar --cmux-memory "$@"
bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --cmux-memory "$@"
bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER "$@"
bundle exec ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar "$@"

# Cleanup
rm _*
