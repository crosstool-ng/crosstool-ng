# This file adds the functions to build the MPFR library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_mpfr_get() { :; }
do_mpfr_extract() { :; }
do_mpfr() { :; }

# Overide function depending on configuration
if [ "${CT_MPFR}" = "y" ]; then

# Download MPFR
do_mpfr_get() {
    CT_GetFile "mpfr-${CT_MPFR_VERSION}" http://www.mpfr.org/mpfr-current/  \
                                 http://www.mpfr.org/mpfr-${CT_MPFR_VERSION}/
}

# Extract MPFR
do_mpfr_extract() {
    CT_Extract "mpfr-${CT_MPFR_VERSION}"
    CT_Patch "mpfr" "${CT_MPFR_VERSION}"

    # OK, Gentoo have a sanity check that libtool.m4 and ltmain.sh have the
    # same version number. Unfortunately, some tarballs of MPFR are not
    # built sanely, and thus ./configure fails on Gentoo.
    # See: http://sourceware.org/ml/crossgcc/2008-05/msg00080.html
    # and: http://sourceware.org/ml/crossgcc/2008-06/msg00005.html
    # This hack is not bad per se, but the MPFR guys would be better not to
    # do that in the future...
    # It seems that MPFR >= 2.4.0 do not need this...
    case "${CT_MPFR_VERSION}" in
        2.4.*)
            CT_Pushd "${CT_SRC_DIR}/mpfr-${CT_MPFR_VERSION}"
            if [ ! -f .autoreconf.ct-ng ]; then
                CT_DoLog DEBUG "Running autoreconf"
                CT_DoExecLog ALL autoreconf
                touch .autoreconf.ct-ng
            fi
            CT_Popd
            ;;
        1.*|2.0.*|2.1.*|2.2.*|2.3.*)
            CT_Pushd "${CT_SRC_DIR}/mpfr-${CT_MPFR_VERSION}"
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
                case "$(libtoolize --version |head -n 1 |awk '{ print $(NF); }')" in
                    0.*)    ;;
                    1.*)    ;;
                    *)      libtoolize_opt=-i;;
                esac
                CT_DoExecLog ALL libtoolize -f ${libtoolize_opt}
                touch .autotools.ct-ng
            fi
            CT_Popd
            ;;
    esac
}

do_mpfr() {
    mkdir -p "${CT_BUILD_DIR}/build-mpfr"
    cd "${CT_BUILD_DIR}/build-mpfr"

    CT_DoStep INFO "Installing MPFR"

    # Under Cygwin, we can't build a thread-safe library
    case "${CT_HOST}" in
        *cygwin*)   mpfr_opts+=( --disable-thread-safe );;
        *mingw*)    mpfr_opts+=( --disable-thread-safe );;
        *darwin*)   mpfr_opts+=( --disable-thread-safe );;
        *)          mpfr_opts+=( --enable-thread-safe  );;
    esac


    CT_DoLog EXTRA "Configuring MPFR"
    CT_DoExecLog CFG                                    \
    CC="${CT_HOST}-gcc"                                 \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                      \
    "${CT_SRC_DIR}/mpfr-${CT_MPFR_VERSION}/configure"   \
        --build=${CT_BUILD}                             \
        --host=${CT_HOST}                               \
        --prefix="${CT_COMPLIBS_DIR}"                   \
        --with-gmp="${CT_COMPLIBS_DIR}"                 \
        --disable-shared                                \
        --enable-static

    CT_DoLog EXTRA "Building MPFR"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking MPFR"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing MPFR"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_MPFR
