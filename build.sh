#!/bin/sh -e

#This script will compile and install a static ffmpeg build with support for nvenc un ubuntu.
#See the prefix path and compile options if edits are needed to suit your needs.

# Based on:  https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
# Based on:  https://gist.github.com/Brainiarc7/3f7695ac2a0905b05c5b
# Rewritten here: https://github.com/ilyaevseev/ffmpeg-build-static/


# Globals
NASM_VERSION="2.15.05"
YASM_VERSION="1.3.0"
LAME_VERSION="3.100"
LASS_VERSION="0.15.2"
CUDA_DIR="/usr/local/cuda"
WORK_DIR="$HOME/ffmpeg-build-static-sources"
DEST_DIR="$HOME/ffmpeg-build-static-binaries"

mkdir -p "$WORK_DIR" "$DEST_DIR" "$DEST_DIR/bin"

export PATH="$DEST_DIR/bin:$PATH"

MYDIR="$(cd "$(dirname "$0")" && pwd)"  #"

####  Routines  ################################################

Wget() { wget -cN "$@"; }

Make() { make -j$(nproc); make "$@"; }

Clone() {
    local DIR="$(basename "$1" .git)"

    cd "$WORK_DIR/"
    test -d "$DIR/.git" || git clone --depth=1 "$@"

    cd "$DIR"
    git pull
}

installLibs() {
sudo apt-get -y --force-yes install \
  autoconf \
  automake \
  build-essential \
  cmake \
  frei0r-plugins-dev \
  gawk \
  libass-dev \
  libfreetype6-dev \
  libopencore-amrnb-dev \
  libopencore-amrwb-dev \
  libspeex-dev \
  libtheora-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvo-amrwbenc-dev \
  libvorbis-dev \
  libwebp-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  libxvidcore-dev \
  pkg-config \
  texi2html \
  zlib1g-dev \
  libdevil-dev

}

installNvidiaSDK() {
    echo "Installing the nVidia NVENC SDK."
    Clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
    make
    make install PREFIX="$DEST_DIR"
    
}

compileNasm() {
    echo "Compiling nasm"
    cd "$WORK_DIR/"
    Wget "http://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.gz"
    tar xzvf "nasm-$NASM_VERSION.tar.gz"
    cd "nasm-$NASM_VERSION"
    ./configure --prefix="$DEST_DIR" --bindir="$DEST_DIR/bin"
    Make install distclean
}

compileYasm() {
    echo "Compiling yasm"
    cd "$WORK_DIR/"
    Wget "http://www.tortall.net/projects/yasm/releases/yasm-$YASM_VERSION.tar.gz"
    tar xzvf "yasm-$YASM_VERSION.tar.gz"
    cd "yasm-$YASM_VERSION/"
    ./configure --prefix="$DEST_DIR" --bindir="$DEST_DIR/bin"
    Make install distclean
}

compileLibX264() {
    echo "Compiling libx264"
    cd "$WORK_DIR/"
    Wget https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2
    rm -rf x264-*/ || :
    tar xjvf x264-master.tar.bz2
    cd x264-master/
    ./configure --prefix="$DEST_DIR" --bindir="$DEST_DIR/bin" --enable-static --enable-pic
    Make install distclean
}

compileLibX265() {
    cd "$WORK_DIR/"
    git -C x265_git pull 2> /dev/null || git clone https://bitbucket.org/multicoreware/x265_git && \
    cd "x265_git/build/linux/"
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$DEST_DIR" -DENABLE_SHARED:bool=off ../../source
    Make install

}

compileLibAom() {
    echo "Compiling libaom"
    Clone https://aomedia.googlesource.com/aom
    mkdir ../aom_build
    cd ../aom_build
    which cmake3 && PROG=cmake3 || PROG=cmake
    $PROG -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$DEST_DIR" -DENABLE_SHARED=off -DENABLE_NASM=on ../aom
    Make install
}

compileLibfdkcc() {
    echo "Compiling libfdk-cc"
    cd "$WORK_DIR/"
    git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac 
    cd fdk-aac
    autoreconf -fiv
    ./configure --prefix="$DEST_DIR" --disable-shared
    Make install distclean
}

compileLibMP3Lame() {
    echo "Compiling libmp3lame"
    cd "$WORK_DIR/"
    Wget "http://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz"
    tar xzvf "lame-$LAME_VERSION.tar.gz"
    cd "lame-$LAME_VERSION"
    ./configure --prefix="$DEST_DIR" --enable-nasm --disable-shared
    Make install distclean
}

compileLibOpus() {
    echo "Compiling libopus"
    Clone https://github.com/xiph/opus.git
    ./autogen.sh
    ./configure --prefix="$DEST_DIR" --disable-shared
    Make install distclean
}

compileLibVpx() {
    echo "Compiling libvpx"
    Clone https://chromium.googlesource.com/webm/libvpx
    ./configure --prefix="$DEST_DIR" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
    Make install clean
}

compileLibAss() {
    echo "Compiling libass"
    cd "$WORK_DIR/"
    Wget "https://github.com/libass/libass/releases/download/$LASS_VERSION/libass-$LASS_VERSION.tar.xz"
    tar Jxvf "libass-$LASS_VERSION.tar.xz"
    cd "libass-$LASS_VERSION"
    autoreconf -fiv
    ./configure --prefix="$DEST_DIR" --disable-shared
    Make install distclean
}

compileFfmpeg(){
    echo "Compiling ffmpeg"
    cd "$WORK_DIR/"
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && 
    tar xjvf ffmpeg-snapshot.tar.bz2 && 
    cd ffmpeg

    export PATH="$CUDA_DIR/bin:$PATH"  # ..path to nvcc
    PKG_CONFIG_PATH="$DEST_DIR/lib/pkgconfig:$DEST_DIR/lib64/pkgconfig" \
    ./configure \
      --pkg-config-flags="--static" \
      --prefix="$DEST_DIR" \
      --bindir="$DEST_DIR/bin" \
      --extra-cflags="-I $DEST_DIR/include -I $CUDA_DIR/include/" \
      --extra-ldflags="-L $DEST_DIR/lib -L $CUDA_DIR/lib64/" \
      --extra-libs="-lpthread" \
      --extra-ldexeflags="-static" \
      --enable-cuda \
      --enable-cuda-sdk \
      --enable-cuda-nvcc \
      --enable-cuvid \
      --enable-libnpp \
      --disable-shared \
      --enable-static \
      --enable-gpl \
      --enable-libfdk-aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libtheora \
      --enable-libvpx \
      --enable-libx264 \
      --enable-nonfree \
      --enable-libaom \
      --enable-nvenc \
      --nvccflags='-gencode arch=compute_75,code=sm_75'
    Make install distclean
    hash -r
}

compileAvisynth(){
#avisynth
Clone https://github.com/AviSynth/AviSynthPlus.git
mkdir avisynth-build && cd avisynth-build 
which cmake3 && PROG=cmake3 || PROG=cmake
PROG ../ -DCMAKE_INSTALL_PREFIX="$DEST_DIR"
Make install

}

compileNVEnc(){
echo "Compiling NVEnc"
cd "$WORK_DIR/"
wget  -O "NVEnc-5.42.tar.gz" "https://github.com/rigaya/NVEnc/archive/refs/tags/5.42.tar.gz"
tar -zxf "NVEnc-5.42.tar.gz"
cd "NVEnc-5.42"
sed -i '/avfilter_register_all()/c\ avfilter_init_dict(0,0)' ./configure

./configure --prefix="$DEST_DIR" --extra-cxxflags="-I $DEST_DIR/include -I $CUDA_DIR/include/" \
--extra-ldflags="-L $DEST_DIR/lib -L $CUDA_DIR/lib64/"
Make install distclean

}

installLibs
installNvidiaSDK

compileNasm
compileYasm
compileLibX264
#compileLibX265
compileLibAom
compileLibVpx
compileLibfdkcc
compileLibMP3Lame
compileLibOpus
#compileLibAss
# TODO: libogg
# TODO: libvorbis
compileFfmpeg

echo "Complete!"

## END ##