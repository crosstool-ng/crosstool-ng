# This file adds the functions to build the MPC library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_mpc_get() { :; }
do_mpc_extract() { :; }
do_mpc_for_build() { :; }
do_mpc_for_host() { :; }

# Overide functions depending on configuration
if [ "${CT_MPC}" = "y" ]; then

# Download MPC
do_mpc_get() {
    CT_GetFile "mpc-${CT_MPC_VERSION}" .tar.gz      \
        {http,ftp,https}://ftp.gnu.org/gnu/mpc      \
        http://www.multiprecision.org/mpc/download
}

# Extract MPC
do_mpc_extract() {
    CT_Extract "mpc-${CT_MPC_VERSION}"
    CT_Patch "mpc" "${CT_MPC_VERSION}"
}

# Build MPC for running on build
# - always build statically
# - we do not have build-specific CFLAGS
# - install in build-tools prefix
do_mpc_for_build() {
    local -a mpc_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing MPC for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpc-build-${CT_BUILD}"

    mpc_opts+=( "host=${CT_BUILD}" )
    mpc_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    mpc_opts+=( "cc=${CT_BUILD_CC}" )
    mpc_opts+=( "cxx=${CT_BUILD_CXX}" )
    mpc_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    mpc_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_mpc_backend "${mpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build MPC for running on host
do_mpc_for_host() {
    local -a mpc_opts

    CT_DoStep INFO "Installing MPC for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpc-host-${CT_HOST}"

    mpc_opts+=( "host=${CT_HOST}" )
    mpc_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    mpc_opts+=( "cc=${CT_HOST_CC}" )
    mpc_opts+=( "cxx=${CT_HOST_CXX}" )
    mpc_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    mpc_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_mpc_backend "${mpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build MPC
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cc            : c compiler to use         : string    : (empty)
#     cxx           : c++ compiler to use       : string    : (empty)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_mpc_backend() {
    local host
    local prefix
    local cc
    local cxx
    local cflags
    local ldflags
    local arg
    local -a env

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring MPC"

    [ -n "${cc}" ] && env+=( "CC=${cc}" )
    [ -n "${cxx}" ] && env+=( "CXX=${cxx}" )
    env+=( "CFLAGS=${cflags}" )
    env+=( "LDFLAGS=${ldflags}" )

    CT_DoExecLog CFG                                \
    "${env[@]}"                                     \
    "${CT_SRC_DIR}/mpc-${CT_MPC_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --with-gmp="${prefix}"                      \
        --with-mpfr="${prefix}"                     \
        --disable-shared                            \
        --enable-static

    CT_DoLog EXTRA "Building MPC"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking MPC"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing MPC"
    CT_DoExecLog ALL make install
}

fi # CT_MPC
