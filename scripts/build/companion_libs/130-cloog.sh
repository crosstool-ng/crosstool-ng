# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog_for_build() { :; }
do_cloog_for_host() { :; }

cloog_basename() {
    printf "cloog"
    if [ "${CT_PPL}" = "y" ]; then
        printf -- "-ppl"
    fi
}
cloog_basename_version() {
    cloog_basename
    printf -- "-${CT_CLOOG_VERSION}"
}

# Overide functions depending on configuration
if [ "${CT_CLOOG}" = "y" ]; then

# Download CLooG
do_cloog_get() {
    CT_GetFile "$(cloog_basename_version)"          \
        http://www.bastoul.net/cloog/pages/download \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract CLooG
do_cloog_extract() {
    local _t

    # Version 0.15.3 has a dirname 'cloog-ppl' (with no version in it!)
    # while versions 0.15.4 onward do have the version in the dirname.
    # But, because the infrastructure properly creates the extracted
    # directories (with tar's --strip-components), we can live safely...
    CT_Extract "$(cloog_basename_version)"
    CT_Patch "$(cloog_basename)" "${CT_CLOOG_VERSION}"

    # Help the autostuff in case it thinks there are things to regenerate...
    CT_DoExecLog DEBUG mkdir -p "${CT_SRC_DIR}/$(cloog_basename_version)/m4"

    if [ "${CT_CLOOG_NEEDS_AUTORECONF}" = "y" ]; then
        CT_Pushd "${CT_SRC_DIR}/$(cloog_basename_version)"
        CT_DoExecLog CFG ./autogen.sh
        CT_Popd
    fi
}

# Build CLooG for running on build
# - always build statically
# - we do not have build-specific CFLAGS
# - install in build-tools prefix
do_cloog_for_build() {
    local -a cloog_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing CLooG for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cloog-build-${CT_BUILD}"

    cloog_opts+=( "host=${CT_BUILD}" )
    cloog_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    cloog_opts+=( "cc=${CT_BUILD_CC}" )
    cloog_opts+=( "cxx=${CT_BUILD_CXX}" )
    cloog_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    cloog_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_cloog_backend "${cloog_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build CLooG for running on host
do_cloog_for_host() {
    local -a cloog_opts

    CT_DoStep INFO "Installing CLooG for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cloog-host-${CT_HOST}"

    cloog_opts+=( "host=${CT_HOST}" )
    cloog_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    cloog_opts+=( "cc=${CT_HOST_CC}" )
    cloog_opts+=( "cxx=${CT_HOST_CXX}" )
    cloog_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    cloog_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_cloog_backend "${cloog_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build CLooG
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cc            : c compiler to use         : string    : (empty)
#     cxx           : c++ compiler to use       : string    : (empty)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_cloog_backend() {
    local host
    local prefix
    local cc
    local cxx
    local cflags
    local ldflags
    local arg
    local -a env
    local -a extra_config
    local -a targets
    local -a install_targets

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring CLooG"

    [ -n "${cc}" ] && env+=( "CC=${cc}" )
    [ -n "${cxx}" ] && env+=( "CXX=${cxx}" )
    env+=( "CFLAGS=${cflags}" )
    env+=( "LDFLAGS=${ldflags}" )
    env+=( "LIBS=-lm" )

    if [ "${CT_CLOOG_0_18_or_later}" = y ]; then
            extra_config+=( "--with-gmp=system" )
            extra_config+=( "--with-gmp-prefix=${prefix}" )
            extra_config+=( "--with-isl=system" )
            extra_config+=( "--with-isl-prefix=${prefix}" )
            extra_config+=( "--without-osl" )
            targets+=( "all" )
            install_targets+=( "install" )
    else
            extra_config+=( "--with-gmp=${prefix}" )
            extra_config+=( "--with-ppl=${prefix}" )
            targets+=( "libcloog.la" )
            install_targets+=( "install-libLTLIBRARIES" )
            install_targets+=( "install-pkgincludeHEADERS" )
    fi

    CT_DoExecLog CFG                                    \
    "${env[@]}"                                         \
    "${CT_SRC_DIR}/$(cloog_basename_version)/configure" \
        --build="${CT_BUILD}"                           \
        --host="${host}"                                \
        --prefix="${prefix}"                            \
        --with-bits=gmp                                 \
        --with-host-libstdcxx="-lstdc++"                \
        --disable-shared                                \
        --enable-static                                 \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building CLooG"
    CT_DoExecLog ALL make ${JOBSFLAGS} "${targets[@]}"

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG"
    CT_DoExecLog ALL make "${install_targets[@]}"
}

fi # CT_CLOOG
