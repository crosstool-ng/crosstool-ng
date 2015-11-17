# This file adds the functions to build the PPL library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_ppl_get() { :; }
do_ppl_extract() { :; }
do_ppl_for_build() { :; }
do_ppl_for_host() { :; }
do_ppl_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_PPL}" = "y" ]; then

# Download PPL
do_ppl_get() {
    CT_GetFile "ppl-${CT_PPL_VERSION}"                                          \
        http://bugseng.com/products/ppl/download/ftp/releases/${CT_PPL_VERSION} \
        ftp://ftp.cs.unipr.it/pub/ppl/releases/${CT_PPL_VERSION}
}

# Extract PPL
do_ppl_extract() {
    CT_Extract "ppl-${CT_PPL_VERSION}"
    CT_Patch "ppl" "${CT_PPL_VERSION}"
}

# Build PPL for running on build
# - always build statically
# - we do not have build-specific CFLAGS
# - install in build-tools prefix
do_ppl_for_build() {
    local -a ppl_opts
    local ppl_cflags
    local ppl_cxxflags

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing PPL for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-ppl-build-${CT_BUILD}"

    ppl_cflags="${CT_CFLAGS_FOR_BUILD}"
    ppl_cxxflags="${CT_CFLAGS_FOR_BUILD}"
    if [ "${CT_PPL_NEEDS_FPERMISSIVE}" = "y" ]; then
        ppl_cxxflags+=" -fpermissive"
    fi

    ppl_opts+=( "host=${CT_BUILD}" )
    ppl_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    ppl_opts+=( "cflags=${ppl_cflags}" )
    ppl_opts+=( "cxxflags=${ppl_cxxflags}" )
    ppl_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_ppl_backend "${ppl_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build PPL for running on host
do_ppl_for_host() {
    local -a ppl_opts
    local ppl_cflags
    local ppl_cxxflags

    CT_DoStep INFO "Installing PPL for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-ppl-host-${CT_HOST}"

    ppl_cflags="${CT_CFLAGS_FOR_HOST}"
    ppl_cxxflags="${CT_CFLAGS_FOR_HOST}"
    if [ "${CT_PPL_NEEDS_FPERMISSIVE}" = "y" ]; then
        ppl_cxxflags+=" -fpermissive"
    fi

    ppl_opts+=( "host=${CT_HOST}" )
    ppl_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    ppl_opts+=( "cflags=${ppl_cflags}" )
    ppl_opts+=( "cxxflags=${ppl_cxxflags}" )
    ppl_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_ppl_backend "${ppl_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build PPL
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_ppl_backend() {
    local host
    local prefix
    local cflags
    local cxxflags
    local ldflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring PPL"

    CT_DoExecLog CFG                                \
    CFLAGS="${cflags}"                              \
    CXXFLAGS="${cxxflags}"                          \
    LDFLAGS="${ldflags}"                            \
    "${CT_SRC_DIR}/ppl-${CT_PPL_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --with-libgmp-prefix="${prefix}"            \
        --with-libgmpxx-prefix="${prefix}"          \
        --with-gmp-prefix="${prefix}"               \
        --enable-watchdog                           \
        --disable-debugging                         \
        --disable-assertions                        \
        --disable-ppl_lcdd                          \
        --disable-ppl_lpsol                         \
        --disable-shared                            \
        --enable-interfaces='c c++'                 \
        --enable-static

    # Maybe-options:
    # --enable-optimization=speed  or sspeed (yes, with 2 's')

    CT_DoLog EXTRA "Building PPL"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking PPL"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing PPL"
    CT_DoExecLog ALL ${make} install

    # Remove spuriously installed file
    CT_DoExecLog ALL rm -f "${prefix}/bin/ppl-config"
}

fi # CT_PPL
