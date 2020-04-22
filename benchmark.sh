#!/bin/bash

WORKDIR=tmp
KVSP_VER=v12

mkdir -p $WORKDIR
cd $WORKDIR

#wget https://github.com/virtualsecureplatform/kvsp/releases/download/$KVSP_VER/kvsp.tar.gz
#tar xf kvsp.tar.gz

mkdir -p elf
kvsp_$KVSP_VER/bin/kvsp cc ../01-fib.c -o elf/01_fib
kvsp_$KVSP_VER/bin/kvsp cc ../02-hamming.c -o elf/02_hamming
kvsp_$KVSP_VER/bin/kvsp cc ../03-bf.c -o elf/03_bf

ruby ../benchmark.rb "$@"
