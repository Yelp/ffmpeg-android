FFMPEG build scripts for Android. Tested on OS X 10.9.4.

For more information about FFmpeg, see https://www.ffmpeg.org/download.html#get-sources.

## How to to build

* Install [autotools](http://www.jattcode.com/installing-autoconf-automake-libtool-on-mac-osx-mountain-lion/) (or just run ./autotools.sh).
* Clone the repo.
* Define where you want NDK installed. DONT use any symbolic links in `$DIR_NDK`.

        $ cd yelp-ffmpeg4android
        $ export DIR_NDK=$(pwd)/ndk

#### Download sources

This will download the sources and generate the toolchain.

    $ ./build_ffmpeg.sh --init

#### Build for the first time

 This will checkout certain library branches and build everything.

    $ ./build_ffmpeg_x86.sh --reset
    $ ./build_ffmpeg_arm.sh --reset

#### Build after changes

This will perform a clean build assuming you have the sources and the toolchain.

    $ ./build_ffmpeg_x86.sh
    $ ./build_ffmpeg_arm.sh

## Output

Check `$DIR_NDK/bin` for executables.
