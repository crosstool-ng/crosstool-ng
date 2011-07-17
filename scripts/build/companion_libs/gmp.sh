# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_gmp_get() { :; }
do_gmp_extract() { :; }
do_gmp_for_host() { :; }

# Overide functions depending on configuration
if [ "${CT_GMP}" = "y" ]; then

# Download GMP
do_gmp_get() {
    CT_GetFile "gmp-${CT_GMP_VERSION}" {ftp,http}://{ftp.sunet.se/pub,ftp.gnu.org}/gnu/gmp
}

# Extract GMP
do_gmp_extract() {
    CT_Extract "gmp-${CT_GMP_VERSION}"
    CT_Patch "gmp" "${CT_GMP_VERSION}"
}

# Build GMP for running on host
do_gmp_for_host() {
    local -a gmp_opts

    CT_DoStep INFO "Installing GMP for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gmp-host-${CT_HOST}"

    gmp_opts+=( "host=${CT_HOST}" )
    gmp_opts+=( "prefix=${CT_COMPLIBS_DIR}" )
    gmp_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    do_gmp_backend "${gmp_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build GMP
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : host cflags to use        : string    : (empty)
do_gmp_backend() {
    local host
    local prefix
    local cflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring GMP"

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags} -fexceptions"                 \
    "${CT_SRC_DIR}/gmp-${CT_GMP_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --enable-fft                                \
        --enable-mpbsd                              \
        --enable-cxx                                \
        --disable-shared                            \
        --enable-static

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking GMP"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL make install
}

fi # CT_GMP
