#!/bin/bash -xe

export CWD="$(pwd)"
export NPROC="$(nproc --all)"

# software versions
export HAPROXY_MAJOR_VERSION=1.7
export HAPROXY_MINOR_VERSION=5
export HAPROXY_VERSION="${HAPROXY_MAJOR_VERSION}.${HAPROXY_MINOR_VERSION}"
export PCRE_VERSION=8.40
export OPENSSL_VERSION=1.1.0e
export ZLIB_VERSION=1.2.11

# source packages
export PCRE_TARBALL="pcre-${PCRE_VERSION}.tar.gz"
export OPENSSL_TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
export ZLIB_TARBALL="zlib-${ZLIB_VERSION}.tar.gz"
export HAPROXY_TARBALL="haproxy-${HAPROXY_VERSION}.tar.gz"
export GLIBC_TARBALL="glibc-${GLIBC_VERSION}.tar.gz"

# haproxy parameters
export USE_STATIC_PCRE=1
export TARGET=linux2628

# build paths
export SSLDIR="${CWD}/openssl-output"
export PCREDIR="${CWD}/pcre-output"
export ZLIBDIR="${CWD}/zlib-output"

# check that required programs are available
for name in "wget" "gcc" "g++" "perl" "patch" "make" ; do
  command -v "${name}" || {
    echo "${name}" is not found in the system, cannot continue
    exit -1
  }
done

# create a new file to set timestamp, we are not using touch since we need the filesystem to provide time (to handle remote FS)
wget -c "http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/${PCRE_TARBALL}" -O "${PCRE_TARBALL}"
wget -c "http://www.openssl.org/source/${OPENSSL_TARBALL}" -O "${OPENSSL_TARBALL}" 
wget -c "http://zlib.net/${ZLIB_TARBALL}" -O "${ZLIB_TARBALL}"
wget -c "http://www.haproxy.org/download/${HAPROXY_MAJOR_VERSION}/src/${HAPROXY_TARBALL}" -O "${HAPROXY_TARBALL}"

for name in "${PCRE_TARBALL}" "${OPENSSL_TARBALL}" "${ZLIB_TARBALL}" "${HAPROXY_TARBALL}" ; do
  tar -k --no-same-owner -xvzf "${name}"
done

# build openssl
cd "${CWD}/openssl-${OPENSSL_VERSION}"
mkdir -p "${SSLDIR}"
./config --prefix="${SSLDIR}" no-shared no-ssl2
make -j"${NPROC}" && make install_sw

# build pcre
mkdir -p "${PCREDIR}"
cd "${CWD}/pcre-${PCRE_VERSION}"
CFLAGS='-O2 -Wall' ./configure --prefix="${PCREDIR}" --disable-shared
make -j"${NPROC}" && make install

# build zlib
mkdir -p "${ZLIBDIR}"
cd "${CWD}/zlib-${ZLIB_VERSION}"
./configure --static --prefix="${ZLIBDIR}"
make -j"${NPROC}" && make install

# patch makefile to allow ZLIBPATHS
mkdir -p "${CWD}/bin"
cd "${CWD}/haproxy-${HAPROXY_VERSION}"
patch -p0 ./Makefile < "${CWD}/Makefile.patch"
sed -ibak "s#PREFIX = /usr/local#PREFIX = ${CWD}/bin#g" Makefile
make -j"${NPROC}" TARGET="${TARGET}" USE_PTHREAD_PSHARED=1 USE_STATIC_PCRE=1 USE_ZLIB=1 USE_OPENSSL=1 ZLIB_LIB="${ZLIBDIR}/lib" ZLIB_INC="${ZLIBDIR}/include" SSL_INC="${SSLDIR}/include" SSL_LIB="${SSLDIR}/lib" ADDLIB=-ldl -lzlib PCREDIR="${PCREDIR}" 
make install
