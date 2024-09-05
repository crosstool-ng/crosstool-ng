# This file adds the functions to build the zstd library
# Copyright 2023 Q. BOSWANK
# Licensed under the GPL v2. See COPYING in the root of this package

do_zstd_get() { :; }
do_zstd_extract() { :; }
do_zstd_for_build() { :; }
do_zstd_for_host() { :; }
do_zstd_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_ZSTD}" = "y" ]; then

# Download zstd
do_zstd_get() {
    CT_Fetch ZSTD
}

# Extract zstd
do_zstd_extract() {
    CT_ExtractPatch ZSTD
}

# Build zstd for running on build
# - always build statically
# - install in build-tools prefix
do_zstd_for_build() {
    local -a zstd_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing zstd for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-zstd-build-${CT_BUILD}"

    zstd_opts+=( "host=${CT_BUILD}" )
    zstd_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    zstd_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    zstd_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )

    do_zstd_backend "${zstd_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build ZSTD zstd running on host
do_zstd_for_host() {
    local -a zstd_opts

    CT_DoStep INFO "Installing zstd for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-zstd-host-${CT_HOST}"

    zstd_opts+=( "host=${CT_HOST}" )
    zstd_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    zstd_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    zstd_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_zstd_backend "${zstd_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build zstd
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_zstd_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Building zstd"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS} -C "${CT_SRC_DIR}/zstd/lib" libzstd.a-nomt-release BUILD_DIR="${PWD}" CC="${host}-gcc" AS="${host}-as" CFLAGS="${cflags}" LDFLAGS="${ldflags}"

    # There is no library only check in zstd

    CT_DoLog EXTRA "Installing zstd"
    CT_DoExecLog ALL make -C "${CT_SRC_DIR}/zstd/lib" install-static install-includes BUILD_DIR="${PWD}" PREFIX="$prefix"
}

fi # CT_ZSTD
