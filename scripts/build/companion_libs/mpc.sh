# This file adds the functions to build the MPC library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_mpc_get() { :; }
do_mpc_extract() { :; }
do_mpc_for_host() { :; }

# Overide functions depending on configuration
if [ "${CT_MPC}" = "y" ]; then

# Download MPC
do_mpc_get() {
    CT_GetFile "mpc-${CT_MPC_VERSION}" .tar.gz      \
        http://www.multiprecision.org/mpc/download
}

# Extract MPC
do_mpc_extract() {
    CT_Extract "mpc-${CT_MPC_VERSION}"
    CT_Patch "mpc" "${CT_MPC_VERSION}"
}

# Build MPC for running on host
do_mpc_for_host() {
    local -a mpc_opts

    CT_DoStep INFO "Installing MPC for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mpc-host-${CT_HOST}"

    mpc_opts+=( "host=${CT_HOST}" )
    mpc_opts+=( "prefix=${CT_COMPLIBS_DIR}" )
    mpc_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    do_mpc_backend "${mpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build MPC
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : host cflags to use        : string    : (empty)
do_mpc_backend() {
    local host
    local prefix
    local cflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring MPC"

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags}"                              \
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
