# This file adds the functions to build the MPFR library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_mpfr_get() { :; }
do_mpfr_extract() { :; }
do_mpfr_for_build() { :; }
do_mpfr_for_host() { :; }
do_mpfr_for_target() { :; }

# Overide function depending on configuration
if [ "${CT_MPFR_TARGET}" = "y" -o "${CT_MPFR}" = "y" ]; then

# Download MPFR
do_mpfr_get() {
    CT_Fetch MPFR
}

# Extract MPFR
do_mpfr_extract() {
    CT_ExtractPatch MPFR

    # TBD is it a problem with 2.4.x? The comment says it is not, yet the code is run
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
    esac
}

# Build MPFR for running on build
# - always build statically
# - install in build-tools prefix
do_mpfr_for_build() {
    local -a mpfr_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing MPFR for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpfr-build-${CT_BUILD}"

    mpfr_opts+=( "host=${CT_BUILD}" )
    mpfr_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    mpfr_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    mpfr_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_mpfr_backend "${mpfr_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build MPFR for running on host
do_mpfr_for_host() {
    local -a mpfr_opts

    CT_DoStep INFO "Installing MPFR for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpfr-host-${CT_HOST}"

    mpfr_opts+=( "host=${CT_HOST}" )
    mpfr_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    mpfr_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    mpfr_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_mpfr_backend "${mpfr_opts[@]}"

    CT_Popd
    CT_EndStep
}

if [ "${CT_MPFR_TARGET}" = "y" ]; then
do_mpfr_for_target() {
    local -a mpfr_opts

    CT_DoStep INFO "Installing MPFR for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpfr-target-${CT_HOST}"

    mpfr_opts+=( "host=${CT_TARGET}" )
    case "${CT_TARGET}" in
        *-*-mingw*)
            prefix="/mingw"
            ;;
        *)
            prefix="/usr"
            ;;
    esac
    mpfr_opts+=( "cflags=${CT_ALL_TARGET_CFLAGS}" )
    mpfr_opts+=( "prefix=${prefix}" )
    mpfr_opts+=( "destdir=${CT_SYSROOT_DIR}" )
    do_mpfr_backend "${mpfr_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

# Build MPFR
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     destdir       : install destination       : dir       : (none)
do_mpfr_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local destdir
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # Under Cygwin, we can't build a thread-safe library
    case "${CT_HOST}" in
        *cygwin*)   extra_config+=( --disable-thread-safe );;
        *mingw*)    extra_config+=( --disable-thread-safe );;
        *darwin*)   extra_config+=( --disable-thread-safe );;
        *)          extra_config+=( --enable-thread-safe  );;
    esac

    if [ "${CT_CC_LANG_JIT}" = "y" ]; then
        extra_config+=("--with-pic")
    fi

    CT_DoLog EXTRA "Configuring MPFR"
    CT_DoExecLog CFG                                    \
    CC="${host}-gcc"                                    \
    CFLAGS="${cflags}"                                  \
    LDFLAGS="${ldflags}"                                \
    ${CONFIG_SHELL}                                     \
    "${CT_SRC_DIR}/mpfr/configure"                      \
        --build=${CT_BUILD}                             \
        --host=${host}                                  \
        --prefix="${prefix}"                            \
        "${extra_config[@]}"                            \
        --with-gmp="${destdir}${prefix}"                \
        --disable-shared                                \
        --enable-static

    # If "${destdir}${prefix}" != "${prefix}" then it means that native MPFR
    # is being built. In this case libgmp.la must be moved away while
    # building MPFR. Otherwise libmpfr.la will contain this:
    #
    #     dependency_libs=' -L<path-to-build-dir>/lib /usr/lib/libgmp.la'
    #
    # Build system then tries to link MPFR with host's libgmp.a. It happens
    # because libgmp.a and libmpfr.a are built with --prefix=/usr while
    # cross-compiling for target and MPFR depends on GMP. In this case
    # libtool thinks that GMP resides in /usr/lib and uses wrong path.
    # The only way to avoid such behavior is to replace libgmp.la
    # temporarily to force libtool using -lgmp option instead wrong one.
    if [ "${destdir}${prefix}" != "${prefix}" ]; then
        if [ -f ${destdir}${prefix}/lib/libgmp.la ]; then
            mv ${destdir}${prefix}/lib/libgmp.la ${destdir}${prefix}/lib/libgmp.la.bk
        fi
    fi

    CT_DoLog EXTRA "Building MPFR"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    if [ -f ${destdir}${prefix}/lib/libgmp.la.bk ]; then
        mv ${destdir}${prefix}/lib/libgmp.la.bk ${destdir}${prefix}/lib/libgmp.la
    fi

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        if [ "${host}" = "${CT_BUILD}" ]; then
            CT_DoLog EXTRA "Checking MPFR"
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -s check
        else
            # Cannot run host binaries on build in a canadian cross
            CT_DoLog EXTRA "Skipping check for MPFR on the host"
        fi
    fi

    CT_DoLog EXTRA "Installing MPFR"
    CT_DoExecLog ALL make install DESTDIR="${destdir}"
}

fi # CT_MPFR
