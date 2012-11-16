# This file adds functions to build elf2flt
# Copyright 2009 John Williams
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Default: do nothing
do_elf2flt_get()        { :; }
do_elf2flt_extract()    { :; }
do_elf2flt_for_build()  { :; }
do_elf2flt_for_host()   { :; }

if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then

# Download elf2flt
do_elf2flt_get() {
    if [ "${CT_ELF2FLT_CUSTOM}" = "y" ]; then
        CT_GetCustom "elf2flt" "${ELF2FLT_VERSION}" \
                     "${CT_ELF2FLT_CUSTOM_LOCATION}"
    else
        CT_GetCVS "elf2flt-${CT_ELF2FLT_VERSION}"               \
                  ":pserver:anonymous@cvs.uclinux.org:/var/cvs" \
                  "elf2flt"                                     \
                  "" \
                  "elf2flt-${CT_ELF2FLT_VERSION}"
    fi
}

# Extract elf2flt
do_elf2flt_extract() {
    # If using custom directory location, nothing to do
    if [    "${CT_ELF2FLT_CUSTOM}" = "y" \
         -a -d "${CT_SRC_DIR}/elf2flt-${CT_ELF2FLT_VERSION}" ]; then
        return 0
    fi
    CT_Extract "elf2flt-${CT_ELF2FLT_VERSION}"
    CT_Patch "elf2flt" "${CT_ELF2FLT_VERSION}"
}

# Build elf2flt for build -> target
do_elf2flt_for_build() {
    local -a elf2flt_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing elf2flt for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-elf2flt-build-${CT_BUILD}"

    elf2flt_opts+=( "host=${CT_BUILD}" )
    elf2flt_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    elf2flt_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    elf2flt_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    elf2flt_opts+=( "binutils_bld=${CT_BUILD_DIR}/build-binutils-build-${CT_HOST}" )

    do_elf2flt_backend "${elf2flt_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build elf2flt for host -> target
do_elf2flt_for_host() {
    local -a elf2flt_opts

    CT_DoStep INFO "Installing elf2flt for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-elf2flt-host-${CT_HOST}"

    elf2flt_opts+=( "host=${CT_HOST}" )
    elf2flt_opts+=( "prefix=${CT_PREFIX_DIR}" )
    elf2flt_opts+=( "static_build=${CT_STATIC_TOOLCHAIN}" )
    elf2flt_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    elf2flt_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    elf2flt_opts+=( "binutils_bld=${CT_BUILD_DIR}/build-binutils-host-${CT_HOST}" )

    do_elf2flt_backend "${elf2flt_opts[@]}"

    # Make those new tools available to the core C compilers to come.
    # Note: some components want the ${TARGET}-{ar,as,ld,strip} commands as
    # well. Create that.
    # Don't do it for canadian or cross-native, because the binutils
    # are not executable on the build machine.
    case "${CT_TOOLCHAIN_TYPE}" in
        cross|native)
            mkdir -p "${CT_BUILDTOOLS_PREFIX_DIR}/${CT_TARGET}/bin"
            mkdir -p "${CT_BUILDTOOLS_PREFIX_DIR}/bin"
            for t in elf2flt flthdr; do
                CT_DoExecLog ALL ln -sv                                         \
                                    "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}"    \
                                    "${CT_BUILDTOOLS_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
                CT_DoExecLog ALL ln -sv                                         \
                                    "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}"    \
                                    "${CT_BUILDTOOLS_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
            done
            ;;
        *)  ;;
    esac

    CT_Popd
    CT_EndStep
}

# Build elf2flt for X -> target
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     static_build  : build statcially          : bool      : no
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_elf2flt_backend() {
    local host
    local prefix
    local static_build
    local cflags
    local ldflags
    local binutils_bld
    local binutils_src
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    binutils_src="${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}"

    CT_DoLog EXTRA "Configuring elf2flt"
    CT_DoExecLog CFG                                            \
    CFLAGS="${cflags}"                                          \
    LDFLAGS="${ldflags}"                                        \
    "${CT_SRC_DIR}/elf2flt-${CT_ELF2FLT_VERSION}/configure"     \
        --build=${CT_BUILD}                                     \
        --host=${host}                                          \
        --target=${CT_TARGET}                                   \
        --prefix=${prefix}                                      \
        --with-bfd-include-dir=${binutils_bld}/bfd              \
        --with-binutils-include-dir=${binutils_src}/include     \
        --with-libbfd=${binutils_bld}/bfd/libbfd.a              \
        --with-libiberty=${binutils_bld}/libiberty/libiberty.a  \
        ${elf2flt_opts}                                         \
        "${CT_ELF2FLT_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building elf2flt"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing elf2flt"
    CT_DoExecLog ALL make install
}

fi # CT_ARCH_BINFMT_FLAT
