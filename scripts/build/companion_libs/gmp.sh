# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_gmp_get() { :; }
do_gmp_extract() { :; }
do_gmp() { :; }
do_gmp_target() { :; }

# Overide functions depending on configuration
if [ "${CT_GMP}" = "y" -o "${CT_GMP_TARGET}" = "y" ]; then

# Download GMP
do_gmp_get() {
    CT_GetFile "gmp-${CT_GMP_VERSION}" {ftp,http}://{ftp.sunet.se/pub,ftp.gnu.org}/gnu/gmp
}

# Extract GMP
do_gmp_extract() {
    CT_Extract "gmp-${CT_GMP_VERSION}"
    CT_Patch "gmp-${CT_GMP_VERSION}"
}

if [ "${CT_GMP}" = "y" ]; then

do_gmp() {

    mkdir -p "${CT_BUILD_DIR}/build-gmp"
    cd "${CT_BUILD_DIR}/build-gmp"

    CT_DoStep INFO "Installing GMP"

    CT_DoLog EXTRA "Configuring GMP"

    CFLAGS="${CT_CFLAGS_FOR_HOST} -fexceptions"     \
    CT_DoExecLog ALL                                \
    "${CT_SRC_DIR}/gmp-${CT_GMP_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --prefix="${CT_PREFIX_DIR}"                 \
        --disable-shared                            \
        --enable-static                             \
        --enable-fft                                \
        --enable-mpbsd                              \
        --enable-cxx

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking GMP"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_GMP

if [ "${CT_GMP_TARGET}" = "y" ]; then

do_gmp_target() {
    mkdir -p "${CT_BUILD_DIR}/build-gmp-target"
    cd "${CT_BUILD_DIR}/build-gmp-target"

    CT_DoStep INFO "Installing GMP for the target"

    CT_DoLog EXTRA "Configuring GMP"
    CFLAGS="${CT_CFLAGS_FOR_TARGET}"                \
    CT_DoExecLog ALL                                \
    "${CT_SRC_DIR}/gmp-${CT_GMP_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_TARGET}                         \
        --prefix=/usr                               \
        --disable-shared                            \
        --enable-static                             \
        --enable-fft                                \
        --enable-mpbsd                              \

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    # Not possible to check MPFR while X-compiling

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" install

    CT_EndStep
}

fi # CT_GMP_TARGET

fi # CT_GMP || CT_GMP_TARGET
