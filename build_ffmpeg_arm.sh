#!/bin/bash

export NUM_JOBS=8
export LEVEL=9
export CPU=arm
export PREFIX=arm-linux-androideabi
export TOOLCHAIN_PREFIX=${PREFIX}
export LIBVPX_TARGET=armv7 
export PIE_FLAGS=""

./build_ffmpeg.sh $@