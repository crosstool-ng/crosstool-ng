# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog_for_build() { :; }
do_cloog_for_host() { :; }

# Overide functions depending on configuration
if [ "${CT_CLOOG}" = "y" ]; then

# Download CLooG
do_cloog_get() {
    CT_GetFile "cloog-ppl-${CT_CLOOG_VERSION}"  \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract CLooG
do_cloog_extract() {
    local _t

    # Version 0.15.3 has a dirname 'cloog-ppl' (with no version in it!)
    # while versions 0.15.4 onward do have the version in the dirname.
    # But, because the infrastructure properly creates the extracted
    # directories (with tar's --strip-components), we can live safely...
    CT_Extract "cloog-ppl-${CT_CLOOG_VERSION}"
    CT_Patch "cloog-ppl" "${CT_CLOOG_VERSION}"

    # Help the autostuff in case it thinks there are things to regenerate...
    CT_DoExecLog DEBUG mkdir -p "${CT_SRC_DIR}/cloog-ppl-${CT_CLOOG_VERSION}/m4"

    if [ "${CT_CLOOG_NEEDS_AUTORECONF}" = "y" ]; then
        CT_Pushd "${CT_SRC_DIR}/cloog-ppl-${CT_CLOOG_VERSION}"
        CT_DoExecLog CFG ./autogen.sh
        CT_Popd
    fi
}

# Build CLooG/PPL for running on build
# - always build statically
# - we do not have build-specific CFLAGS
# - install in build-tools prefix
do_cloog_for_build() {
    local -a cloog_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing CLooG/PPL for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cloog-ppl-build-${CT_BUILD}"

    cloog_opts+=( "host=${CT_BUILD}" )
    cloog_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    do_cloog_backend "${cloog_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build CLooG/PPL for running on host
do_cloog_for_host() {
    local -a cloog_opts

    CT_DoStep INFO "Installing CLooG/PPL for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cloog-ppl-host-${CT_HOST}"

    cloog_opts+=( "host=${CT_HOST}" )
    cloog_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    cloog_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    do_cloog_backend "${cloog_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build ClooG/PPL
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : host cflags to use        : string    : (empty)
do_cloog_backend() {
    local host
    local prefix
    local cflags
    local cloog_src_dir="${CT_SRC_DIR}/cloog-ppl-${CT_CLOOG_VERSION}"
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring CLooG/ppl"

    CT_DoExecLog CFG                            \
    CFLAGS="${cflags}"                          \
    LIBS="-lm"                                  \
    "${cloog_src_dir}/configure"                \
        --build=${CT_BUILD}                     \
        --host=${host}                          \
        --prefix="${prefix}"                    \
        --with-gmp="${prefix}"                  \
        --with-ppl="${prefix}"                  \
        --with-bits=gmp                         \
        --with-host-libstdcxx='-lstdc++'        \
        --disable-shared                        \
        --enable-static

    CT_DoLog EXTRA "Building CLooG/ppl"
    CT_DoExecLog ALL make ${JOBSFLAGS} libcloog.la

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG/ppl"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG/ppl"
    CT_DoExecLog ALL make install-libLTLIBRARIES install-pkgincludeHEADERS
}

fi # CT_CLOOG
