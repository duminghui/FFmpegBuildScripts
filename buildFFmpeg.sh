#!/bin/bash
set -e
ROOT_DIR=`pwd`
ROOT_BUILD="$ROOT_DIR/libs4android"
PLATFORM=android-15
PROJECT_NAME=
TOOLCHAIN=
SYSROOT=
CROSS_PREFIX=
CRT_PREFIX=
CC=
LD=
AS=
AR=
RANLIB=
STRIP=
NM=
echo "== ROOT_DIR:$ROOT_DIR"
echo "== ROOT_BUILD:$ROOT_BUILD"

# 暂时先支持arm
init_toolchain(){
    echo "=================init toolchain==================="
    local abi="$1"
    local toolchain
    if [ "$abi" == "arm" -o "$abi" == "armv7-a" ]; then
        TOOLCHAIN="$ROOT_BUILD/toolchain/arm-$PLATFORM"
        SYSROOT="$TOOLCHAIN/sysroot"
        CROSS_PREFIX="$TOOLCHAIN/bin/arm-linux-androideabi-"
        CRT_PREFIX="$TOOLCHAIN/lib/gcc/arm-linux-androideabi/4.9.x"
        toolchain=arm-linux-androideabi-4.9
    else
        echo "==E: No support abi:'$abi'"
        exit 1
    fi
    CC="${CROSS_PREFIX}gcc"
    LD="${CROSS_PREFIX}ld"
    AS="${CROSS_PREFIX}gcc"
    AR="${CROSS_PREFIX}ar"
    RANLIB="${CROSS_PREFIX}ranlib"
    STRIP="${CROSS_PREFIX}strip"
    NM="${CROSS_PREFIX}nm"
    if [ ! -d "$TOOLCHAIN" ]; then
        echo "== Make standalon toolchian"
        # --deprecated-header fix in android undefined reference to 'stderr'
        $NDK_HOME/build/tools/make-standalone-toolchain.sh --verbose --arch=arm --platform=$PLATFORM --install-dir="$TOOLCHAIN --deprecated-headers" --toolchain="$toolchain"
    fi
    echo "== TOOLCHAIN:$TOOLCHAIN"
    # echo "== PATH:$PATH"
    echo "== CROSS_PREFIX:$CROSS_PREFIX"
    echo "== CC:$CC"
    echo "== LD:$LD"
    echo "== AS:$AS"
    echo "== AR:$AR"
    echo "== RANLIB:$RANLIB"
    echo "== STRIP:$STRIP"
    echo "== NM:$NM"
    echo "== SYSROOT:$SYSROOT"
}

SOURCE_DIR=
DEST_DIR=
BACK_DIR=

init_need_dirs () {
    PROJECT_NAME="$1"
    if [ ! "$PROJECT_NAME" ]; then
        echo "==E: PROJECT_NAME is empty"
        exit 1
    fi
    SOURCE_DIR="$ROOT_DIR/$PROJECT_NAME"
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "==E: Can't find '$PROJECT_NAME' source code"
        exit 1
    fi
    DEST_DIR="$ROOT_BUILD/$PROJECT_NAME"
    echo "== *Remove DEST_DIR:$DEST_DIR"
    rm -rf "$DEST_DIR"
    BACK_DIR="$ROOT_DIR/bak/$PROJECT_NAME"
    if [ ! -d "$BACK_DIR" ]; then
        echo "== Mkdir back dir:$BACK_DIR"
        mkdir -pv "$BACK_DIR"
    fi
    echo "== $PROJECT_NAME SOURCE_DIR:$SOURCE_DIR"
    echo "== $PROJECT_NAME DEST_DIR:$DEST_DIR"
    echo "== $PROJECT_NAME BACK_DIR:$BACK_DIR"
}

build_ffmpeg () {
    local abi="$1"
    init_toolchain "$abi"
    if [ ! -s "$BACK_DIR/configure" ]; then
        echo "== back $SOURCE_DIR/configure to $BACK_DIR"
        cp "$SOURCE_DIR/configure" "$BACK_DIR"
    fi
    cd "$SOURCE_DIR"
    sed -i .bak \
        -e "s/LIBNAME='\$(LIBPREF)\$(FULLNAME)\$(LIBSUF)'/LIBNAME='\$(LIBPREF)\$(FULLNAME)-\$(LIBMAJOR)\$(LIBSUF)'/g" \
        -e "s/SLIBNAME_WITH_MAJOR='\$(SLIBNAME).\$(LIBMAJOR)'/SLIBNAME_WITH_MAJOR='\$(SLIBPREF)\$(FULLNAME)-\$(LIBMAJOR)\$(SLIBSUF)'/g" \
        -e "s/LIB_INSTALL_EXTRA_CMD='\$\$(RANLIB) \"\$(LIBDIR)\/\$(LIBNAME)\"'/LIB_INSTALL_EXTRA_CMD='\$\$(RANLIB) \"\$(LIBDIR)\/\$(LIBNAME)\"'/g" \
        -e "s/SLIB_INSTALL_NAME='\$(SLIBNAME_WITH_VERSION)'/SLIB_INSTALL_NAME='\$(SLIBNAME_WITH_MAJOR)'/g" \
        -e "s/SLIB_INSTALL_LINKS='\$(SLIBNAME_WITH_MAJOR) \$(SLIBNAME)'/SLIB_INSTALL_LINKS='\$(SLIBNAME)'/g" \
        configure

    local ffmpeg_prefix="$DEST_DIR/$abi"
    if [ ! -d "$ffmpeg_prefix" ]; then
        echo "== *Mkdir FFmpeg_Prefix:$ffmpeg_prefix"
        mkdir -pv "$ffmpeg_prefix"
    fi

    local arch=
    if [ "$abi" == "arm" -o "$abi" == "armv7-a" ]; then
        arch='arm'
    fi
    local ffmpeg_flags=" \
        --prefix="$ffmpeg_prefix" \
        --target-os=linux \
        --arch=$arch \
        --enable-cross-compile \
        --cross-prefix="$CROSS_PREFIX" \
        --sysroot="$SYSROOT"
        --cc=$CC \
        --nm=$NM \
        --enable-neon \
        --enable-asm \
        --disable-yasm \
        --enable-small \
        --enable-gpl \
        --enable-nonfree \
        --enable-version3 \
        --disable-shared \
        --enable-static \
        --disable-symver \
        --disable-doc \
        --disable-ffplay \
        --disable-ffmpeg \
        --disable-ffprobe \
        --disable-ffserver \
        --enable-zlib \
        --disable-pthreads \
        --disable-swresample \
        --disable-avdevice \
        --enable-avfilter \
        --enable-filters \
        --disable-devices \
        --disable-muxers \
        --enable-muxer=mov \
        --enable-muxer=ipod \
        --enable-muxer=psp \
        --enable-muxer=mp4 \
        --enable-muxer=avi \
        --disable-demuxers \
        --enable-demuxer=h264 \
        --enable-demuxer=avi \
        --enable-demuxer=mpc \
        --enable-demuxer=mov \
        --disable-encoders \
        --enable-encoder=aac \
        --disable-decoders \
        --enable-decoder=aac \
        --enable-decoder=aac_latm \
        --enable-decoder=mpeg4 \
        --enable-decoder=h264 \
        --disable-parsers \
        --enable-parser=aac \
        --enable-parser=ac3 \
        --enable-parser=h264 \
        --disable-protocols \
        --enable-protocol=file \
        --disable-bsfs \
        --enable-bsf=aac_adtstoasc \
        --enable-bsf=h264_mp4toannexb \
        --disable-indevs \
        --disable-outdevs \
        "
    local ffmpeg_flags=" \
        --prefix="$ffmpeg_prefix" \
        --target-os=linux \
        --arch=$arch \
        --enable-cross-compile \
        --cross-prefix="$CROSS_PREFIX" \
        --sysroot="$SYSROOT"
        --cc=$CC \
        --nm=$NM \
        --enable-neon \
        --enable-asm \
        --disable-yasm \
        --enable-small \
        --enable-gpl \
        --enable-nonfree \
        --enable-version3 \
        --disable-shared \
        --enable-static \
        --disable-symver \
        --disable-doc \
        --disable-ffplay \
        --disable-ffmpeg \
        --disable-ffprobe \
        --disable-ffserver \
        --enable-zlib \
        --disable-pthreads \
        --enable-swresample \
        --disable-avdevice \
        --enable-avfilter \
        --enable-filters \
        --disable-devices \
        --enable-muxers \
        --enable-demuxers \
        --enable-encoders \
        --enable-decoders \
        --enable-parsers \
        --enable-protocols \
        --enable-bsfs \
        --disable-indevs \
        --disable-outdevs \
        "

    local extra_cflags="-Os -fPIC -DANDROID -marm -mfpu=neon -I$SYSROOT/usr/include"
    # local extra_ldflags="-Wl,-T,$TOOLCHAIN/arm-linux-androideabi/lib/ldscripts/armelf_linux_eabi.x -Wl,-rpath-link=$SYSROOT/usr/lib -L$SYSROOT/usr/lib -nostdlib $CRT_PREFIX/crtbegin.o $CRT_PREFIX/crtend.o -lc -lm -ldl -marm"
    # local extra_ldflags="-Wl,-rpath-link=$SYSROOT/usr/lib -L$SYSROOT/usr/lib -nostdlib $CRT_PREFIX/crtbegin.o $CRT_PREFIX/crtend.o -lc -lm -ldl -marm"
    # local extra_cflags=" -fPIC -DANDROID -mfpu=neon -mfloat-abi=softfp -I$SYSROOT/usr/include"
    ### 这里直接使用生成的sysroot在Android工程中会出错undefined reference to 'stderr'
    # local extra_cflags=" -fPIC -DANDROID -mfpu=neon -mfloat-abi=softfp -I$NDK_HOME/platforms/android-19/arch-arm/usr/include"
    local extra_ldflags="-marm -L$SYSROOT/usr/lib"
    if [ "$abi" == "armv7-a" ]; then
        # extra_cflags="$extra_cflags -D__ARM_ARCH_7__ -D__ARM_ARCH_7A__ -march=armv7-a -mfloat-abi=softfp"
        extra_cflags="$extra_cflags -march=armv7-a -mfloat-abi=softfp"
        extra_ldflags="$extra_ldflags -march=armv7-a -Wl,--fix-cortex-a8"
        # extra_ldflags="$extra_ldflags -march=armv7-a"
        ffmpeg_flags="$ffmpeg_flags --cpu=armv7-a"
    fi
    echo "== extra_cflags:$extra_cflags"
    echo "== extra_ldflags:$extra_ldflags"
    echo "=======Start configure $SOURCE_DIR:$abi====="
    ./configure $ffmpeg_flags --extra-cflags="$extra_cflags" --extra-ldflags="$extra_ldflags"

    echo "== ./configure success"

    # sed -i .bak \
    #     -e "s/#define HAVE_LOG2 1/#define HAVE_LOG2 0/g" \
    #     -e "s/#define HAVE_LOG2F 1/#define HAVE_LOG2F 0/g" \
    #     -e "s/#define HAVE_LOG10F 1/#define HAVE_LOG10F 0/g" \
    #     -e "s/#define HAVE_CBRT 0/#define HAVE_CBRT 1/g" \
    #     -e "s/#define HAVE_COPYSIGN 0/#define HAVE_COPYSIGN 1/g" \
    #     -e "s/#define HAVE_ERF 0/#define HAVE_ERF 1/g" \
    #     -e "s/#define HAVE_ISNAN 0/#define HAVE_ISNAN 1/g" \
    #     -e "s/#define HAVE_ISFINITE 0/#define HAVE_ISFINITE 1/g" \
    #     -e "s/#define HAVE_HYPOT 0/#define HAVE_HYPOT 1/g" \
    #     -e "s/#define HAVE_LRINT 0/#define HAVE_LRINT 1/g" \
    #     -e "s/#define HAVE_LRINTF 0/#define HAVE_LRINTF 1/g" \
    #     config.h

    make clean
    make
    make install

    # 以下删除的是防止在合并成一个so文件时出现重复定义的情况
    # echo "=======make all o to one so file========="
    # if [ -s "$SOURCE_DIR/libavutil/log2_tab.o" ]; then
    #     rm "$SOURCE_DIR/libavutil/log2_tab.o"
    # fi
    # if [ -s "$SOURCE_DIR/libavcodec/reverse.o" ]; then
    #     rm "$SOURCE_DIR/libavcodec/reverse.o"
    # fi
    # if [ -s "$SOURCE_DIR/libavcodec/log2_tab.o" ]; then
    #     rm "$SOURCE_DIR/libavcodec/log2_tab.o"
    # fi
    # if [ -s "$SOURCE_DIR/libswresample/log2_tab.o" ]; then
    #     rm "$SOURCE_DIR/libswresample/log2_tab.o"
    # fi
    # if [ -s "$SOURCE_DIR/libavformat/golomb_tab.o" ]; then
    #     rm "$SOURCE_DIR/libavformat/golomb_tab.o"
    # fi
    # if [ -s ""$SOURCE_DIR/libavformat/log2_tab.o ]; then
    #     rm "$SOURCE_DIR/libavformat/log2_tab.o"
    # fi
    # local lib_file="$ffmpeg_prefix/lib$PROJECT_NAME.so"
    # local lib_debug_file="$ffmpeg_prefix/lib$PROJECT_NAME-debug.so"

    # "$CC" -llog -lm -lz -shared --sysroot="$SYSROOT" -Wl,-z,noexecstack compat/*.o libavutil/*.o libavutil/arm/*.o libavcodec/*.o libavcodec/arm/*.o libavformat/*.o libswscale/*.o -o "$lib_file"
    # cp "$lib_file" "$lib_debug_file"
    # "$STRIP" --strip-unneeded "$lib_file"

    # echo "success make on so file"
}

init_need_dirs ffmpeg-3.3.3
# build_ffmpeg "arm"
build_ffmpeg "armv7-a"
