#!/bin/bash

WORKDIR=tmp

mkdir -p $WORKDIR
cd $WORKDIR

wget https://github.com/virtualsecureplatform/kvsp/releases/download/v11/kvsp.tar.gz
tar xf kvsp.tar.gz

mkdir -p elf
kvsp_v11/bin/kvsp cc ../01-fib.c -o elf/01_fib
kvsp_v11/bin/kvsp cc ../02-hamming.c -o elf/02_hamming
kvsp_v11/bin/kvsp cc ../03-bf.c -o elf/03_bf

ruby ../benchmark.rb $1
