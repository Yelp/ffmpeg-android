#!/bin/bash

export NUM_JOBS=8
export LEVEL=16
export CPU=arm
export PREFIX=arm-linux-androideabi
export TOOLCHAIN_PREFIX=${PREFIX}
export LIBVPX_TARGET=armv7
# This is a bit hacky. C'est le bash scripts.
export PIE_ENABLED="-fPIE -pie"

./build_ffmpeg.sh $@