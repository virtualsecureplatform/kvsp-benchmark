#!/bin/bash -eu

### Usage
# ./benchmark.sh [-g NGPUS]
###

KVSP_VER=14

# Download kvsp if not exist
if [ ! -f "kvsp_v$KVSP_VER/bin/kvsp" ]; then
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v$KVSP_VER/kvsp.tar.gz | \
    tar zx
fi

# Run
ruby benchmark.rb --kvsp-ver $KVSP_VER --superscalar --cmux-memory "$@"
ruby benchmark.rb --kvsp-ver $KVSP_VER --cmux-memory "$@"

# Cleanup
rm _*
