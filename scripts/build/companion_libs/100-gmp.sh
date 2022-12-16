# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_gmp_get() { :; }
do_gmp_extract() { :; }
do_gmp_for_build() { :; }
do_gmp_for_host() { :; }
do_gmp_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_GMP_TARGET}" = "y" -o  "${CT_GMP}" = "y" ]; then

# Download GMP
do_gmp_get() {
    CT_Fetch GMP
}

# Extract GMP
do_gmp_extract() {
    CT_ExtractPatch GMP
}

# Build GMP for running on build
# - always build statically
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

if [ "${CT_GMP_TARGET}" = "y" ]; then
do_gmp_for_target() {
    local -a gmp_opts

    CT_DoStep INFO "Installing GMP for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gmp-target-${CT_HOST}"

    gmp_opts+=( "host=${CT_TARGET}" )
    case "${CT_TARGET}" in
        *-*-mingw*)
            prefix="/mingw"
            ;;
        *)
            prefix="/usr"
            ;;
    esac
    gmp_opts+=( "cflags=${CT_ALL_TARGET_CFLAGS}" )
    gmp_opts+=( "prefix=${prefix}" )
    gmp_opts+=( "destdir=${CT_SYSROOT_DIR}" )
    gmp_opts+=( "shared=${CT_SHARED_LIBS}" )
    do_gmp_backend "${gmp_opts[@]}"

    CT_Popd
    CT_EndStep
}
fi

# Build GMP
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     destdir       : install destination       : dir       : (none)
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

    # To avoid “illegal text-relocation” linking error against
    # the static library, see:
    #     https://github.com/Homebrew/homebrew-core/pull/25470
    case "${host}" in
        *darwin*)
            extra_config+=("--with-pic")
            ;;
    esac

    if [ "${CT_CC_LANG_JIT}" = "y" ]; then
        extra_config+=("--with-pic")
    fi

    # GMP's configure script doesn't respect the host parameter
    # when not cross-compiling, ie when build == host so set
    # CC_FOR_BUILD and CPP_FOR_BUILD.
    CT_DoExecLog CFG                                \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
    CPP_FOR_BUILD="{CT_BUILD}-cpp"                  \
    CC="${host}-gcc"                                \
    CFLAGS="${cflags} -fexceptions"                 \
    LDFLAGS="${ldflags}"                            \
    ${CONFIG_SHELL}                                 \
    "${CT_SRC_DIR}/gmp/configure"                   \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --prefix="${prefix}"                        \
        --enable-fft                                \
        --enable-cxx                                \
        --disable-shared                            \
        --enable-static                             \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        if [ "${host}" = "${CT_BUILD}" ]; then
            CT_DoLog EXTRA "Checking GMP"
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -s check
        else
            # Cannot run host binaries on build in a canadian cross
            CT_DoLog EXTRA "Skipping check for GMP on the host"
        fi
    fi

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL make install DESTDIR="${destdir}"
}

fi # CT_GMP
