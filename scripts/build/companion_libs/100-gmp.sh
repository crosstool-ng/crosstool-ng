# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_gmp_get() { :; }
do_gmp_extract() { :; }
do_gmp_for_build() { :; }
do_gmp_for_host() { :; }
do_gmp_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_GMP}" = "y" ]; then

# Download GMP
do_gmp_get() {
    CT_GetFile "gmp-${CT_GMP_VERSION}"         \
        https://gmplib.org/download/gmp        \
        {http,ftp,https}://ftp.gnu.org/gnu/gmp
}

# Extract GMP
do_gmp_extract() {
    CT_Extract "gmp-${CT_GMP_VERSION}"
    CT_Patch "gmp" "${CT_GMP_VERSION}"
}

# Build GMP for running on build
# - always build statically
# - we do not have build-specific CFLAGS
# - install in build-tools prefix
do_gmp_for_build() {
    local -a gmp_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing GMP for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gmp-build-${CT_BUILD}"

    gmp_opts+=( "host=${CT_BUILD}" )
    gmp_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    gmp_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    gmp_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_gmp_backend "${gmp_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build GMP for running on host
do_gmp_for_host() {
    local -a gmp_opts

    CT_DoStep INFO "Installing GMP for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gmp-host-${CT_HOST}"

    gmp_opts+=( "host=${CT_HOST}" )
    gmp_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    gmp_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    gmp_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_gmp_backend "${gmp_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build GMP
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_gmp_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring GMP"

    if [ ! "${CT_GMP_5_0_2_or_later}" = "y" ]; then
        extra_config+=("--enable-mpbsd")
    fi

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags} -fexceptions"                 \
    LDFLAGS="${ldflags}"                            \
    "${CT_SRC_DIR}/gmp-${CT_GMP_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --enable-fft                                \
        --enable-cxx                                \
        --disable-shared                            \
        --enable-static                             \
        "${extra_config}"

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking GMP"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL ${make} install
}

fi # CT_GMP
