#!/bin/bash

export NUM_JOBS=8
export LEVEL=9
export CPU=x86
export PREFIX=i686-linux-android
export TOOLCHAIN_PREFIX=${CPU}
export LIBVPX_TARGET=x86
export PIE_FLAGS=""

./build_ffmpeg.sh $@