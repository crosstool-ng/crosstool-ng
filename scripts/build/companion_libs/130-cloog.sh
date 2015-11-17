# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog_for_build() { :; }
do_cloog_for_host() { :; }
do_cloog_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_CLOOG}" = "y" ]; then

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
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_cloog_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local cloog_src_dir="${CT_SRC_DIR}/$(cloog_basename_version)"
    local arg
    local -a cloog_opts
    local -a cloog_targets
    local -a cloog_install_targets

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    if [ "${CT_CLOOG_0_18_or_later}" = y ]; then
            cloog_opts+=( --with-gmp=system --with-gmp-prefix="${prefix}" )
            cloog_opts+=( --with-isl=system --with-isl-prefix="${prefix}" )
            cloog_opts+=( --without-osl )
            cloog_targets=( all )
            cloog_install_targets=( install )
    else
            cloog_opts+=( --with-gmp="${prefix}" )
            cloog_opts+=( --with-ppl="${prefix}" )
            cloog_targets=( libcloog.la )
            cloog_install_targets=( install-libLTLIBRARIES install-pkgincludeHEADERS )
    fi

    CT_DoLog EXTRA "Configuring CLooG"

    CT_DoExecLog CFG                            \
    CFLAGS="${cflags}"                          \
    LDFLAGS="${ldflags}"                        \
    LIBS="-lm"                                  \
    "${cloog_src_dir}/configure"                \
        --build=${CT_BUILD}                     \
        --host=${host}                          \
        --prefix="${prefix}"                    \
        --with-bits=gmp                         \
        --with-host-libstdcxx='-lstdc++'        \
        --disable-shared                        \
        --enable-static                         \
        "${cloog_opts[@]}"

    CT_DoLog EXTRA "Building CLooG"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS} "${cloog_targets[@]}"

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG"
    CT_DoExecLog ALL ${make} "${cloog_install_targets[@]}"
}

fi # CT_CLOOG
