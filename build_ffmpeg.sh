#!/bin/bash

set -e

ORIGINAL_PATH=${PATH}

if [ ! "$1" = "" ] && [ ! "$1" = "--init" ] && [ ! "$1" = "--reset" ]; then
    printf "Usage:\n"
    printf "    $0 --init\n"
    printf "            To download NDK, FFMPEG, and the dependencies.\n"
    printf "    $0\n"
    printf "            To build everything.\n"
    printf "    $0 --reset\n"
    printf "            To build everything, forcing a 'git checkout -- .' on all components.\n"
    exit 1
fi

if [ ! -n "${DIR_NDK}" ]; then
    printf "You need to specify the following environment variables:\n"
    printf "    DIR_NDK - NDK root directory [DO NOT USE SYMBOLIC LINKS]\n"
    exit 1
fi

LOG_FILE="$(pwd)/build_ffmpeg.log"
printf "" > ${LOG_FILE}

# Initialize ndk and toolchain.

if [ "$1" = "--init" ]; then

    # Download ndk.

    printf "NDK\n"

    if [ ! -f android-ndk-r12b-darwin-x86_64.zip ]; then
        printf "    downloading r12b for mac\n"
        curl "https://dl.google.com/android/repository/android-ndk-r12b-darwin-x86_64.zip" \
            -o android-ndk-r12b-darwin-x86_64.zip \
            >> ${LOG_FILE} 2>&1
    fi

    printf "    unzipping\n"
    unzip android-ndk-r12b-darwin-x86_64.zip \
        >> ${LOG_FILE} 2>&1

    printf "    moving to ${DIR_NDK}\n"
    rm -rf ${DIR_NDK} || true
    mkdir -p ${DIR_NDK} \
        >> ${LOG_FILE} 2>&1
    mv android-ndk-r12b/* ${DIR_NDK} \
        >> ${LOG_FILE} 2>&1

    printf "    done\n"

    # Download sources.

    printf "SOURCES\n"
    cd ${DIR_NDK}/sources \
        >> ${LOG_FILE} 2>&1

    printf "    cloning yasm\n"
    git clone --progress git://github.com/yasm/yasm.git \
        >> ${LOG_FILE} 2>&1

    printf "    cloning ogg\n"
    git clone --progress git://git.xiph.org/mirrors/ogg.git \
        >> ${LOG_FILE} 2>&1

    printf "    downloading vorbis\n"
    curl "http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.4.tar.gz" \
        -o libvorbis-1.3.4.tar.gz \
        >> ${LOG_FILE} 2>&1
    tar xzvf libvorbis-1.3.4.tar.gz \
        >> ${LOG_FILE} 2>&1
    rm libvorbis-1.3.4.tar.gz \
        >> ${LOG_FILE} 2>&1
    rm -rf libvorbis \
        >> ${LOG_FILE} 2>&1
    mv libvorbis-1.3.4 libvorbis \
        >> ${LOG_FILE} 2>&1

    printf "    cloning vpx\n"
    (git clone --progress https://chromium.googlesource.com/webm/libvpx.git libvpx) \
        >> ${LOG_FILE} 2>&1

    printf "    cloning ffmpeg\n"
    (git clone --progress git://source.ffmpeg.org/ffmpeg.git ffmpeg) \
        >> ${LOG_FILE} 2>&1

    SOURCE_LIST=$(ls ${DIR_NDK}/sources)
    printf "    done\n"
    printf "${SOURCE_LIST}"
    exit 0
fi

if [ ! -d "${DIR_NDK}/sources/ffmpeg" ]; then
    printf "NDK not found. Run './build_ffmpeg.sh --init' to download everything.\n"
    exit 1
fi

# Verify input variables. PIE_FLAGS do not need to be set and are disabled by default.
if [ ! -n "${NUM_JOBS}" ] || [ ! -n "${LEVEL}" ] || [ ! -n "${CPU}" ] ||
   [ ! -n "${PREFIX}" ] || [ ! -n "${TOOLCHAIN_PREFIX}" ] || [ ! -n "${LIBVPX_TARGET}" ]; then

    printf "You need to specify the following environment variables:\n"
    printf "    NUM_JOBS - Number of threads to use for make [1:]\n"
    printf "    LEVEL - Android platform level, should be one from\n"
    printf "          ~/\$DIR_NDK/platforms/android-* [9:19]\n"
    printf "    CPU - Android CPU architecture, should be one from\n"
    printf "          ~/\$DIR_NDK/platforms/android-\$LEVEL/arch-* [arm / x86]\n"
    printf "    PREFIX - Android toolchain executable prefix\n"
    printf "             [arm-linux-androideabi / i686-linux-android]\n"
    printf "    TOOLCHAIN_PREFIX - Android toolchain folder prefix\n"
    printf "             [arm-linux-androideabi / x86]\n"
    printf "    LIBVPX_TARGET - See \"libvpx/configure --help\" [armv7 / x86]\n"
    exit 1
fi

# Determine the output directory and put PIE executables in their own separate path.
# Also set whether --enable-pic is passed to FFmpeg's configuration to generate PIE executables.
if [[ $PIE_FLAGS ]]; then
    ffmpegOutputDir=${DIR_NDK}/bin/${CPU}/pie
    enablePic="--enable-pic"
else
    ffmpegOutputDir=${DIR_NDK}/bin/${CPU}
    enablePic=""
fi

# Setup the android ndk toolchain to cross compile.
DIR_SYSROOT=${DIR_NDK}/platforms/android-${LEVEL}/arch-${CPU}/usr

if [ ! -d "${DIR_SYSROOT}/bin" ]; then
    printf "TOOLCHAIN\n"
    TOOLCHAIN=${TOOLCHAIN_PREFIX}-4.9

    printf "    generating\n"
    ${DIR_NDK}/build/tools/make-standalone-toolchain.sh \
        --platform=android-${LEVEL} \
        --toolchain=${TOOLCHAIN} \
        --install-dir=${DIR_SYSROOT} \
        --stl=stlport \
        >> ${LOG_FILE} 2>&1

    printf "    done ${DIR_SYSROOT}\n"
fi

# Make the executables executable.
chmod -R u+x ${DIR_NDK} \
    >> ${LOG_FILE} 2>&1

# Build YASM.
printf "YASM\n"
cd ${DIR_NDK}/sources/yasm \
    >> ${LOG_FILE} 2>&1

if [ "$1" = "--reset" ] || [ "$1" = "--init" ]; then
    printf "    resetting\n"
    git checkout -- . \
        >> ${LOG_FILE} 2>&1
    (git checkout 4c2772c3f90fe66c21642f838e73dba20284fb0a \
        >> ${LOG_FILE} 2>&1) || true
fi

printf "    cleaning\n"
(make clean \
    >> ${LOG_FILE} 2>&1) || true

printf "    configuring\n"
./autogen.sh --host=${PREFIX} --prefix=${DIR_SYSROOT} \
    >> ${LOG_FILE} 2>&1

printf "    building\n"
make -j${NUM_JOBS} \
    >> ${LOG_FILE} 2>&1

printf "    installing\n"
make install \
    >> ${LOG_FILE} 2>&1

printf "    done\n    "
ls ${DIR_SYSROOT}/lib | grep libyasm.a
# Done building libyasm.a.


# Build libogg.
printf "LIBOGG\n"
export PATH=${ORIGINAL_PATH}:${DIR_SYSROOT}/bin
export RANLIB=${DIR_SYSROOT}/bin/${PREFIX}-ranlib
cd ${DIR_NDK}/sources/ogg \
    >> ${LOG_FILE} 2>&1

if [ "$1" = "--reset" ] || [ "$1" = "--init" ]; then
    printf "    resetting\n"
    git checkout -- . \
        >> ${LOG_FILE} 2>&1
    git checkout ab78196fd59ad7a329a2b19d2bcec5d840a9a21f \
        >> ${LOG_FILE} 2>&1 || true
fi

printf "    cleaning\n"
make clean \
    >> ${LOG_FILE} 2>&1 || true

printf "    configuring\n"
./autogen.sh --prefix=${DIR_SYSROOT} --host=${PREFIX} --with-sysroot=${DIR_SYSROOT} \
    --disable-shared \
    >> ${LOG_FILE} 2>&1

printf "    building\n"
make -j${NUM_JOBS} \
    >> ${LOG_FILE} 2>&1

printf "    installing\n"
make install \
    >> ${LOG_FILE} 2>&1

printf "    done\n    "
ls ${DIR_SYSROOT}/lib | grep libogg.a
unset RANLIB
export PATH=${ORIGINAL_PATH}
# Done building libogg.a and libogg.la.


# Build libvorbis.
printf "LIBVORBIS\n"
export CC=${DIR_SYSROOT}/bin/${PREFIX}-gcc
export CXX=${DIR_SYSROOT}/bin/${PREFIX}-g++
export LD=${DIR_SYSROOT}/bin/${PREFIX}-ld
export STRIP=${DIR_SYSROOT}/bin/${PREFIX}-strip
export NM=${DIR_SYSROOT}/bin/${PREFIX}-nm
export AR=${DIR_SYSROOT}/bin/${PREFIX}-ar
export AS=${DIR_SYSROOT}/bin/${PREFIX}-as
export RANLIB=${DIR_SYSROOT}/bin/${PREFIX}-ranlib
cd ${DIR_NDK}/sources/libvorbis \
    >> ${LOG_FILE} 2>&1

printf "    cleaning\n"
make clean \
    >> ${LOG_FILE} 2>&1 || true

printf "    configuring\n"
./configure --prefix=${DIR_SYSROOT} --host=${PREFIX} --with-sysroot=${DIR_SYSROOT} \
    --disable-shared \
    >> ${LOG_FILE} 2>&1

printf "    building\n"
make -j${NUM_JOBS} \
    >> ${LOG_FILE} 2>&1

printf "    installing\n"
make install \
    >> ${LOG_FILE} 2>&1

printf "    done\n    "
ls ${DIR_SYSROOT}/lib | grep libvorbis.a
unset CC CXX LD STRIP NM AR AS RANLIB
# libvorbis.a done.

# Build libvpx.
printf "LIBVPX\n"
export CROSS=${DIR_SYSROOT}/bin/${PREFIX}-
cd ${DIR_NDK}/sources/libvpx \
    >> ${LOG_FILE} 2>&1

if [ "$1" = "--reset" ] || [ "$1" = "--init" ]; then
    printf "    resetting\n"
    git checkout -- . \
        >> ${LOG_FILE} 2>&1
    git checkout tags/v1.3.0 \
        >> ${LOG_FILE} 2>&1
    git checkout -B v1.3.0 \
        >> ${LOG_FILE} 2>&1
    git checkout v1.3.0 \
        >> ${LOG_FILE} 2>&1
    git pull origin tags/v1.3.0 \
        >> ${LOG_FILE} 2>&1
fi

printf "    cleaning\n"
make clean \
    >> ${LOG_FILE} 2>&1 || true

printf "    configuring\n"
./configure --target=${LIBVPX_TARGET}-android-gcc --sdk-path=${DIR_NDK} --prefix=${DIR_SYSROOT} \
    --disable-vp9 --disable-examples --disable-runtime-cpu-detect --disable-realtime-only \
    --enable-vp8-encoder --enable-vp8-decoder \
    >> ${LOG_FILE} 2>&1

printf "    building\n"
make -j${NUM_JOBS} \
    >> ${LOG_FILE} 2>&1

printf "    installing\n"
make install \
    >> ${LOG_FILE} 2>&1

printf "    done\n    "
ls ${DIR_SYSROOT}/lib | grep libvpx.a
unset CROSS
# libvpx.a finished building.


# Build FFmpeg.
printf "FFMPEG\n"
export PATH=${ORIGINAL_PATH}:${DIR_SYSROOT}/bin
cd ${DIR_NDK}/sources/ffmpeg \
    >> ${LOG_FILE} 2>&1

if [ "$1" = "--reset" ] || [ "$1" = "--init" ]; then
    printf "    resetting\n"
    git checkout -- . \
        >> ${LOG_FILE} 2>&1
    git checkout release/3.0 \
        >> ${LOG_FILE} 2>&1
    git pull \
        >> ${LOG_FILE} 2>&1
fi

printf "    cleaning\n"
make clean \
    >> ${LOG_FILE} 2>&1 || true

printf "    configuring\n"
./configure \
    --prefix=${DIR_SYSROOT} --arch=${CPU} --target-os=linux \
    --extra-ldflags="-L${DIR_SYSROOT}/lib ${PIE_FLAGS}" \
    --extra-cflags="-I${DIR_SYSROOT}/include ${PIE_FLAGS}" \
    --extra-cxxflags="-I${DIR_SYSROOT}/include ${PIE_FLAGS}" \
    --enable-cross-compile --cross-prefix=${PREFIX}- --sysroot=${DIR_SYSROOT} \
    --disable-shared --enable-static --enable-small \
    --disable-all --enable-ffmpeg \
    --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-avfilter --enable-swscale \
    --enable-filter=aresample --enable-filter=crop --enable-filter=scale --enable-filter=transpose \
    --enable-protocol=file \
    --enable-libvorbis --enable-libvpx \
    --enable-decoder=aac --enable-decoder=amrnb --enable-decoder=amrwb --enable-decoder=flac --enable-decoder=mp3 --enable-decoder=libvorbis --enable-decoder=adpcm_ima_wav \
    --enable-decoder=h263 --enable-decoder=h263p --enable-decoder=h264 --enable-decoder=mpeg4 --enable-decoder=libvpx_vp8 \
    --enable-demuxer=concat \
    --enable-demuxer=mov --enable-demuxer=mpegts --enable-demuxer=webm --enable-demuxer=matroska \
    --enable-encoder=libvorbis \
    --enable-encoder=libvpx_vp8 \
    --enable-muxer=webm \
    $enablePic \
        >> ${LOG_FILE} 2>&1

printf "    building\n"
make -j${NUM_JOBS} \
    >> ${LOG_FILE} 2>&1

printf "    installing\n"
make install \
    >> ${LOG_FILE} 2>&1

printf "    done\n    "
ls ${DIR_SYSROOT}/bin | grep ffmpeg
export PATH=${ORIGINAL_PATH}

# Copy executable to output directory.
mkdir -p $ffmpegOutputDir \
    >> ${LOG_FILE} 2>&1
cp ${DIR_SYSROOT}/bin/ffmpeg $ffmpegOutputDir \
    >> ${LOG_FILE} 2>&1
printf "Android ffmpeg executable in ${ffmpegOutputDir}/\n\0"
