# This file adds the functions to build the MPC library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_mpc_get() { :; }
do_mpc_extract() { :; }
do_mpc() { :; }

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

do_mpc() {
    local -a mpc_opts

    mkdir -p "${CT_BUILD_DIR}/build-mpc"
    cd "${CT_BUILD_DIR}/build-mpc"

    CT_DoStep INFO "Installing MPC"

    CT_DoLog EXTRA "Configuring MPC"

    if [ "${CT_COMPLIBS_SHARED}" = "y" ]; then
        mpc_opts+=( --enable-shared --disable-static )
    else
        mpc_opts+=( --disable-shared --enable-static )
    fi

    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CT_DoExecLog CFG                                \
    "${CT_SRC_DIR}/mpc-${CT_MPC_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --prefix="${CT_COMPLIBS_DIR}"               \
        --with-gmp="${CT_COMPLIBS_DIR}"             \
        --with-mpfr="${CT_COMPLIBS_DIR}"            \
        "${mpc_opts[@]}"

    CT_DoLog EXTRA "Building MPC"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking MPC"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing MPC"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_MPC
