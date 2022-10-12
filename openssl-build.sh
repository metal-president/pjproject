#!/bin/sh

# https://github.com/openssl/openssl/issues/18720
# export GIT_TAG="OpenSSL_1_1_1q"
GIT_URL="git@github.com:openssl/openssl.git"
GIT_TAG="OpenSSL_1_1_1p"

PATH_ROOT="$(pwd)"
PATH_SOURCE="openssl"
PATH_OUTPUTS="${PATH_ROOT}/${PATH_SOURCE}-libs"
PATH_COMBINE="${PATH_OUTPUTS}/all"

DEVELOPER=`xcode-select -print-path`
CLANG="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

ARCHS="arm64 x86_64"

# if [ "${DEBUG}" == "true" ]; then
#   echo "Compiling for debugging ..."
#   OPT_CFLAGS="-O0 -fno-inline -g"
#   OPT_LDFLAGS=""
#   OPT_CONFIG_ARGS="--enable-assertions --disable-asm"
# else
#   OPT_CFLAGS="-Ofast -flto -g"
#   OPT_LDFLAGS="-flto"
#   OPT_CONFIG_ARGS=""
# fi

set -e

build() {
  export CC="${CLANG} -arch $1"

  # simulator
  if [ "$1" == 'x86_64' ]; then
    IPHONESDK="iPhoneSimulator.sdk"
    PLATFORM="iPhoneSimulator"
    CONFIGURE="iphoneos-cross"

  else
    IPHONESDK="iPhoneOS.sdk"
    PLATFORM="iPhoneOS"
    CONFIGURE="ios64-cross"
  fi

  DEVPATH="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  PATH_OUTPUTS_TARGET="${PATH_OUTPUTS}/$1"
  rm -rf "${PATH_OUTPUTS_TARGET}"

  echo "clone ${GIT_TAG}"
  rm -rf "${PATH_SOURCE}"
  git clone ${GIT_URL} -b ${GIT_TAG}
  cd "${PATH_SOURCE}"

  export CROSS_TOP="${DEVPATH}"
  export CROSS_SDK="${IPHONESDK}"
  export PATH="${DEVPATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"

  ./Configure ${CONFIGURE} no-shared no-dso no-hw no-engine --prefix="${PATH_OUTPUTS_TARGET}"
  make
  # make test
  make install
}

rm -rf "${PATH_COMBINE}"
mkdir -p "${PATH_COMBINE}"
mkdir -p "${PATH_COMBINE}/lib"

for ARCH in ${ARCHS}; do
  build "${ARCH}"
done

OUTPUT_LIBS="libcrypto.a libssl.a"
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
