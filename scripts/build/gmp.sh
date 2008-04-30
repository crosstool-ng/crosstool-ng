# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() {
    [ "${CT_CC_GCC_GMP_MPFR}" = "y" ] || return 0
    echo "gmp-${CT_GMP_VERSION}"
}

# Download GMP
do_gmp_get() {
    CT_GetFile "${CT_GMP_FILE}"                 \
               http://ftp.sunet.se/pub/gnu/gmp  \
               ftp://ftp.gnu.org/gnu/gmp
}

# Extract GMP
do_gmp_extract() {
    CT_ExtractAndPatch "${CT_GMP_FILE}"
}

do_gmp() {
    mkdir -p "${CT_BUILD_DIR}/build-gmp"
    cd "${CT_BUILD_DIR}/build-gmp"

    CT_DoStep INFO "Installing GMP"

    CT_DoLog EXTRA "Configuring GMP"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"              \
    "${CT_SRC_DIR}/${CT_GMP_FILE}/configure"    \
        --build=${CT_BUILD}                     \
        --host=${CT_HOST}                       \
        --prefix="${CT_PREFIX_DIR}"             \
        --disable-shared --enable-static        \
        --enable-fft --enable-mpbsd             2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Building GMP"
    make ${PARALLELMFLAGS}  2>&1 |CT_DoLog ALL

    if [ "${CT_GMP_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking GMP"
        make -s check       2>&1 |CT_DoLog ALL
    fi

    CT_DoLog EXTRA "Installing GMP"
    make install            2>&1 |CT_DoLog ALL

    CT_EndStep
}
