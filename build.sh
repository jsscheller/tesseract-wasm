#!/bin/bash
set -euo pipefail

fn_git_clean() {
  git clean -xdf
  git checkout .
}

OUT_DIR="$PWD/out"
ROOT="$PWD"
EMCC_FLAGS_DEBUG="-Os -g3"
EMCC_FLAGS_RELEASE="-Oz -flto"

export CPPFLAGS="-I$OUT_DIR/include"
export LDFLAGS="-L$OUT_DIR/lib"
export PKG_CONFIG_PATH="$OUT_DIR/lib/pkgconfig"
export EM_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
export CFLAGS="$EMCC_FLAGS_RELEASE"
export CXXFLAGS="$CFLAGS"
export CHOST="wasm32-unknown-linux" # wasm32-unknown-emscripten

mkdir -p "$OUT_DIR"

cd "$ROOT/lib/zlib-ng"
fn_git_clean
emconfigure ./configure \
  --prefix="$OUT_DIR" \
  --static \
  --zlib-compat \
  --without-optimizations \
  --without-acle \
  --without-neon
emmake make -j install

cd "$ROOT/lib/libjpeg-turbo"
fn_git_clean
# https://github.com/libjpeg-turbo/libjpeg-turbo/issues/250#issuecomment-407615180
emcmake cmake \
  -B_build \
  -H. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$OUT_DIR" \
  -DENABLE_STATIC=TRUE \
  -DENABLE_SHARED=FALSE \
  -DWITH_JPEG8=TRUE \
  -DWITH_SIMD=FALSE \
  -DWITH_TURBOJPEG=FALSE
emmake make -C _build install

cd "$ROOT/lib/libpng"
fn_git_clean
emconfigure ./configure \
  --host="$CHOST" \
  --prefix="$OUT_DIR" \
  --enable-static \
  --disable-shared \
  --disable-dependency-tracking \
  --disable-hardware-optimizations \
  --disable-unversioned-libpng-config \
  --without-binconfigs
emmake make -j install dist_man_MANS= bin_PROGRAMS=

cd "$ROOT/lib/tiff"
fn_git_clean
patch -p1 < ../../patches/tiff.patch
autoreconf -fiv
chmod +x ./configure
emconfigure ./configure \
  --prefix="$OUT_DIR" \
  --disable-shared \
  CFLAGS="$CFLAGS"
emmake make -j install

cd "$ROOT/lib/leptonica"
fn_git_clean
./autobuild
emconfigure ./configure \
  --host="$CHOST" \
  --prefix="$OUT_DIR" \
  --enable-static \
  --disable-shared \
  --disable-programs \
  --without-giflib \
  --without-libwebp \
  --without-libopenjpeg
emmake make -j install

cd "$ROOT/lib/tesseract"
# fn_git_clean
# ./autogen.sh
emconfigure ./configure \
  --host="$CHOST" \
  --prefix="$OUT_DIR" \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --without-archive \
  --disable-openmp \
  --disable-legacy \
  --disable-graphics \
  --disable-dependency-tracking \
  --without-curl
emmake make -j install

mkdir -p "$ROOT/dist"
cd "$ROOT/lib/tesseract"
/bin/bash ./libtool \
  --tag=CXX \
  --mode=link \
  emcc \
  $LDFLAGS \
  $CFLAGS \
  --closure 1 \
  --pre-js "$ROOT/js/pre.js" \
  --post-js "$ROOT/js/post.js" \
  -s WASM_BIGINT=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORTED_RUNTIME_METHODS='["callMain","FS","NODEFS","WORKERFS","ENV"]' \
  -s INCOMING_MODULE_JS_API='["noInitialRun","noFSInit","locateFile","preRun"]' \
  -s NO_DISABLE_EXCEPTION_CATCHING=1 \
  -s MODULARIZE=1 \
  -o "$ROOT/dist/tesseract.js" \
  "$ROOT/lib/tesseract/src/tesseract-tesseract.o" \
  -lnodefs.js \
  -lworkerfs.js \
  -ltiff \
  -lpng \
  -ljpeg \
  -lz \
  -llept \
  -ltesseract

rm -rf "$ROOT/dist/tessdata"
cp -R "$OUT_DIR/share/tessdata" "$ROOT/dist/tessdata"
