# This file adds the functions to build the MPFR library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() { :; }
do_mpfr_get() { :; }
do_mpfr_extract() { :; }
do_mpfr() { :; }
do_mpfr_target() { :; }

# Overide function depending on configuration
if [ "${CT_GMP_MPFR}" = "y" ]; then

do_print_filename() {
    [ "${CT_GMP_MPFR}" = "y" ] || return 0
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
    # This hack is not bad per se, but the MPFR guys would be better not to
    # do that in the future...
    CT_Pushd "${CT_SRC_DIR}/${CT_MPFR_FILE}"
    if [ ! -f .autotools.ct-ng ]; then
        CT_DoLog DEBUG "Re-building autotools files"
        CT_DoExecLog ALL autoreconf -fi
        # Starting with libtool-1.9f, config.{guess,sub} are no longer
        # installed without -i, but starting with libtool-2.2.6, they
        # are no longer removed without -i. Sight... Just use -i with
        # libtool >=2
        # See: http://sourceware.org/ml/crossgcc/2008-11/msg00046.html
        # and: http://sourceware.org/ml/crossgcc/2008-11/msg00048.html
        libtoolize_opt=
        case "$(libtoolize --version |head -n 1 |gawk '{ print $(NF); }')" in
            0.*)    ;;
            1.*)    ;;
            *)      libtoolize_opt=-i;;
        esac
        CT_DoExecLog ALL libtoolize -f ${libtoolize_opt}
        touch .autotools.ct-ng
    fi
    CT_Popd
}

do_mpfr() {
    mkdir -p "${CT_BUILD_DIR}/build-mpfr"
    cd "${CT_BUILD_DIR}/build-mpfr"

    CT_DoStep INFO "Installing MPFR"

    CT_DoLog EXTRA "Configuring MPFR"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"              \
    CT_DoExecLog ALL                            \
    "${CT_SRC_DIR}/${CT_MPFR_FILE}/configure"   \
        --build=${CT_BUILD}                     \
        --host=${CT_HOST}                       \
        --prefix="${CT_PREFIX_DIR}"             \
        --enable-thread-safe                    \
        --disable-shared --enable-static        \
        --with-gmp="${CT_PREFIX_DIR}"

    CT_DoLog EXTRA "Building MPFR"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    if [ "${CT_MPFR_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking MPFR"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing MPFR"
    CT_DoExecLog ALL make install

    CT_EndStep
}

if [ "${CT_GMP_MPFR_TARGET}" = "y" ]; then

do_mpfr_target() {
    mkdir -p "${CT_BUILD_DIR}/build-mpfr-target"
    cd "${CT_BUILD_DIR}/build-mpfr-target"

    CT_DoStep INFO "Installing MPFR for the target"

    CT_DoLog EXTRA "Configuring MPFR"
    CFLAGS="${CT_CFLAGS_FOR_TARGET}"            \
    CT_DoExecLog ALL                            \
    "${CT_SRC_DIR}/${CT_MPFR_FILE}/configure"   \
        --build=${CT_BUILD}                     \
        --host=${CT_TARGET}                     \
        --prefix=/usr                           \
        --enable-thread-safe                    \
        --disable-shared --enable-static        \
        --with-gmp="${CT_SYSROOT_DIR}/usr"

    CT_DoLog EXTRA "Building MPFR"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    # Not possible to check MPFR while X-compiling

    CT_DoLog EXTRA "Installing MPFR"
    CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" install

    CT_EndStep
}

fi # CT_GMP_MPFR_TARGET == y

fi # CT_GMP_MPFR == y
