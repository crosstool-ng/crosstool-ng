# This file adds the functions to build the zlib library
# Copyright 2017 Alexey Neyman
# Licensed under the GPL v2. See COPYING in the root of this package

do_zlib_get() { :; }
do_zlib_extract() { :; }
do_zlib_for_build() { :; }
do_zlib_for_host() { :; }
do_zlib_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_ZLIB}" = "y" ]; then

# Download zlib
do_zlib_get() {
    CT_GetFile "zlib-${CT_ZLIB_VERSION}"         \
        "http://downloads.sourceforge.net/project/libpng/zlib/${CT_ZLIB_VERSION}"
}

# Extract zlib
do_zlib_extract() {
    CT_Extract "zlib-${CT_ZLIB_VERSION}"
    CT_Patch "zlib" "${CT_ZLIB_VERSION}"
}

# Build zlib for running on build
# - always build statically
# - install in build-tools prefix
do_zlib_for_build() {
    local -a zlib_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing zlib for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-zlib-build-${CT_BUILD}"

    zlib_opts+=( "host=${CT_BUILD}" )
    zlib_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    zlib_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    zlib_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_zlib_backend "${zlib_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build zlib for running on host
do_zlib_for_host() {
    local -a zlib_opts

    CT_DoStep INFO "Installing zlib for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-zlib-host-${CT_HOST}"

    zlib_opts+=( "host=${CT_HOST}" )
    zlib_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    zlib_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    zlib_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_zlib_backend "${zlib_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build zlib
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_zlib_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring zlib"

    CT_DoExecLog CFG                                  \
    CFLAGS="${cflags}"                                \
    LDFLAGS="${ldflags}"                              \
    CHOST="${host}"                                   \
    ${CONFIG_SHELL}                                   \
    "${CT_SRC_DIR}/zlib-${CT_ZLIB_VERSION}/configure" \
        --prefix="${prefix}"                          \
        --static                                      \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building zlib"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        if [ "${host}" = "${CT_BUILD}" ]; then
            CT_DoLog EXTRA "Checking zlib"
            CT_DoExecLog ALL make ${JOBSFLAGS} -s check
        else
            # Cannot run host binaries on build in a canadian cross
            CT_DoLog EXTRA "Skipping check for zlib on the host"
        fi
    fi

    CT_DoLog EXTRA "Installing zlib"
    CT_DoExecLog ALL make install
}

fi # CT_ZLIB
