# This file adds the functions to build the MPFR library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

if [ "${CT_CC_GCC_GMP_MPFR}" = "y" ]; then

do_print_filename() {
    [ "${CT_CC_GCC_GMP_MPFR}" = "y" ] || return 0
    echo "mpfr-${CT_MPFR_VERSION}"
}

# Download MPFR
do_mpfr_get() {
    CT_GetFile "${CT_MPFR_FILE}" http://www.mpfr.org/mpfr-current/          \
                                 http://www.mpfr.org/mpfr-${CT_MPFR_VERSION}/
}

# Extract MPFR
do_mpfr_extract() {
    CT_ExtractAndPatch "${CT_MPFR_FILE}"

    # OK, Gentoo have a sanity check that libtool.m4 and ltmain.sh have the
    # same version number. Unfortunately, some tarballs of MPFR are not
    # built sanely, and thus ./configure fails on Gentoo.
    # See: http://sourceware.org/ml/crossgcc/2008-05/msg00080.html
    # and: http://sourceware.org/ml/crossgcc/2008-06/msg00005.html
    # This hack is not bad per se, but the MPFR guys would be better to not
    # do that in the future...
    CT_Pushd "${CT_SRC_DIR}/${CT_MPFR_FILE}"
    autoreconf -fi  2>&1 |CT_DoLog ALL
    libtoolize      2>&1 |CT_DoLog ALL
    CT_Popd
}

do_mpfr() {
    mkdir -p "${CT_BUILD_DIR}/build-mpfr"
    cd "${CT_BUILD_DIR}/build-mpfr"

    CT_DoStep INFO "Installing MPFR"

    CT_DoLog EXTRA "Configuring MPFR"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                          \
    "${CT_SRC_DIR}/${CT_MPFR_FILE}/configure"               \
        --build=${CT_BUILD}                                 \
        --host=${CT_HOST}                                   \
        --prefix="${CT_PREFIX_DIR}"                         \
        --enable-thread-safe                                \
        --disable-shared --enable-static                    \
        --with-gmp="${CT_PREFIX_DIR}"                       2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Building MPFR"
    make ${PARALLELMFLAGS}  2>&1 |CT_DoLog ALL

    if [ "${CT_MPFR_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking MPFR"
        make -s check       2>&1 |CT_DoLog ALL
    fi

    CT_DoLog EXTRA "Installing MPFR"
    make install            2>&1 |CT_DoLog ALL

    CT_EndStep
}

else # No MPFR

do_print_filename() { :; }
do_mpfr_get() { :; }
do_mpfr_extract() { :; }
do_mpfr() { :; }

fi
