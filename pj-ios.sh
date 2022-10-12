#!/bin/sh

PATH_ROOT="$(pwd)"
PATH_PJ="pjsip"

PATH_OPEN_SSL="openssl"
PATH_OPEN_SSL_LIBS="${PATH_ROOT}/openssl-libs"
PATH_OUTPUTS="${PATH_ROOT}/${PATH_PJ}-libs"

APP_XCODE="Xcode.app"
PATH_XCODE="/Applications/${APP_XCODE}"
CLANG="${PATH_XCODE}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

export MIN_IOS="-miphoneos-version-min=13.0"

cd "${PATH_ROOT}"

ARCHS="x86_64 arm64"

build() {
  # arm64
  if [ "$1" == 'arm64' ]; then
    export DEVPATH="${PATH_XCODE}/Contents/Developer/Platforms/iPhoneOS.platform/Developer"
    export IPHONESDK="iPhoneOS.sdk"
    export ARCH="-arch arm64"
  # export CC="${CLANG} -arch arm64 -fembed-bitcode"
    export CC="${CLANG} -arch arm64"
    unset CFLAGS
    unset LDFLAGS
  # export CFLAGS="-O2 -m64"
  # export LDFLAGS="-O2 -m64"
    export CONFIGURE="ios64-cross"
    export PATH_OPEN_SSL_TARGET="${PATH_OPEN_SSL_LIBS}/arm64"

  # x86_64
  elif [ "$1" == 'x86_64' ]; then
    export DEVPATH="${PATH_XCODE}/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer"
    export IPHONESDK="iPhoneSimulator.sdk"
    export ARCH="-arch x86_64"
  # export CC="${CLANG} -arch x86_64 -fembed-bitcode"
    export CC="${CLANG} -arch x86_64"
    export CFLAGS="-O2 -m64 -mios-simulator-version-min=13.0"
    export LDFLAGS="-O2 -m64 -mios-simulator-version-min=13.0"
    export CONFIGURE="iphoneos-cross"
    export PATH_OPEN_SSL_TARGET="${PATH_OPEN_SSL_LIBS}/x86_64"

  fi

  # ./configure-iphone  --with-ssl=${PATH_OPEN_SSL_TARGET} --with-opus=${PATH_OPUS} --disable-darwin-ssl
  ./configure-iphone  --with-ssl=${PATH_OPEN_SSL_TARGET} --disable-darwin-ssl
  make distclean
  make dep && make clean && make
}

merge() {
  PKG=$1
  PATH_COMBINE="${PATH_OUTPUTS}/${PKG}"
  mkdir -p "${PATH_COMBINE}"
  for OUTPUT_LIB in $2; do
    INPUT_LIBS=""
    for ARCH in ${ARCHS}; do
      if [ "$ARCH" == 'arm64' ]; then
        SUFFIX="arm64-apple-darwin_ios"
      elif [ "$ARCH" == 'x86_64' ]; then
        SUFFIX="x86_64-apple-darwin_ios"
      fi

      INPUT_ARCH_LIB="${PATH_ROOT}/${PKG}/lib/${OUTPUT_LIB}-${SUFFIX}.a"
      echo $INPUT_ARCH_LIB
      if [ -e $INPUT_ARCH_LIB ]; then
        INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
      fi
      # Combine the three architectures into a universal library.
      if [ -n "$INPUT_LIBS"  ]; then
        lipo -create $INPUT_LIBS -output "${PATH_COMBINE}/${OUTPUT_LIB}.a"
        lipo -info "${PATH_COMBINE}/${OUTPUT_LIB}.a"
      else
        echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
      fi
    done
  done
}

rm -rf "${PATH_OUTPUTS}"

for ARCH in ${ARCHS}; do
  build "${ARCH}"
done

mkdir -p "${PATH_OUTPUTS}"

merge "pjlib" "libpj"
merge "pjlib-util" "libpjlib-util"
merge "pjmedia" "libpjmedia libpjmedia-audiodev libpjmedia-codec libpjmedia-videodev libpjsdp"
merge "pjnath" "libpjnath"
merge "pjsip" "libpjsip libpjsip-simple libpjsip-ua libpjsua libpjsua2"
merge "third_party" "libg7221codec libgsmcodec libilbccodec libresample libspeex libsrtp libwebrtc libyuv"
