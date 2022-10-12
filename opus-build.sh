#!/bin/sh

GIT_URL="git@github.com:xiph/opus.git"
OPUS_VERSION="1.3.1"

PATH_ROOT="$(pwd)"
PATH_SOURCE="opus-${OPUS_VERSION}"
PATH_OUTPUTS="${PATH_ROOT}/${PATH_SOURCE}-libs"
PATH_COMBINE="${PATH_OUTPUTS}/all"

DEVELOPER=`xcode-select -print-path`
CLANG="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
MINIOSVERSION="13.0"

ARCHS="arm64 x86_64"

if [ "${DEBUG}" == "true" ]; then
    echo "Compiling for debugging ..."
    OPT_CFLAGS="-O0 -fno-inline -g"
    OPT_LDFLAGS=""
    OPT_CONFIG_ARGS="--enable-assertions --disable-asm"
else
    OPT_CFLAGS="-Ofast -flto -g"
    OPT_LDFLAGS="-flto"
    OPT_CONFIG_ARGS=""
fi

set -e

build() {
  export CC="${CLANG} -arch $1"

  # simulator
  if [ "$1" == 'x86_64' ]; then
    IPHONESDK="iPhoneSimulator.sdk"
    PLATFORM="iPhoneSimulator"
    EXTRA_CFLAGS="-arch ${ARCH}"
    EXTRA_CONFIG="--host=x86_64-apple-darwin"

  else
    IPHONESDK="iPhoneOS.sdk"
    PLATFORM="iPhoneOS"
    EXTRA_CFLAGS="-arch ${ARCH}"
    EXTRA_CONFIG="--host=arm-apple-darwin"
  fi

  DEVPATH="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  PATH_OUTPUTS_TARGET="${PATH_OUTPUTS}/$1"
  rm -rf "${PATH_OUTPUTS_TARGET}"

	echo "Downloading opus-${OPUS_VERSION}.tar.gz"
	curl -LO http://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz
  echo "Using opus-${OPUS_VERSION}.tar.gz"

  tar zxf opus-${OPUS_VERSION}.tar.gz  -C .
  cd "${PATH_SOURCE}"

	./configure --enable-float-approx --disable-shared --enable-static --with-pic --disable-extra-programs --disable-doc ${EXTRA_CONFIG} \
    --prefix="${PATH_OUTPUTS_TARGET}" \
    LDFLAGS="$LDFLAGS ${OPT_LDFLAGS} -fPIE -miphoneos-version-min=${MINIOSVERSION} -L${PATH_OUTPUTS_TARGET}/lib" \
    CFLAGS="$CFLAGS ${EXTRA_CFLAGS} ${OPT_CFLAGS} -fPIE -miphoneos-version-min=${MINIOSVERSION} -I${PATH_OUTPUTS_TARGET}/include -isysroot ${DEVPATH}/SDKs/${IPHONESDK}" \

	make -j4
	make install
	make clean
}

rm -rf "${PATH_COMBINE}"
mkdir -p "${PATH_COMBINE}"
mkdir -p "${PATH_COMBINE}/lib"

for ARCH in ${ARCHS}; do
  build "${ARCH}"
done

OUTPUT_LIBS="libopus.a"
for OUTPUT_LIB in ${OUTPUT_LIBS}; do
  INPUT_LIBS=""
  for ARCH in ${ARCHS}; do
    INPUT_ARCH_LIB="${PATH_OUTPUTS}/${ARCH}/lib/${OUTPUT_LIB}"
    if [ -e $INPUT_ARCH_LIB ]; then
      INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
    fi
  done
  # Combine the three architectures into a universal library.
  if [ -n "$INPUT_LIBS"  ]; then
    lipo -create $INPUT_LIBS -output "${PATH_COMBINE}/lib/${OUTPUT_LIB}"
    lipo -info "${PATH_COMBINE}/lib/${OUTPUT_LIB}"
  else
    echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
  fi
done
