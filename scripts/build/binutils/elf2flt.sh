# This file adds functions to build elf2flt
# Copyright 2009 John Williams
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Default: do nothing
do_elf2flt_get()     { :; }
do_elf2flt_extract() { :; }
do_elf2flt()         { :; }

if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then

# Download elf2flt
do_elf2flt_get() {
    CT_GetCVS "elf2flt-cvs-${CT_ELF2FLT_VERSION}"           \
              ":pserver:anonymous@cvs.uclinux.org:/var/cvs" \
              "elf2flt"                                     \
              "" \
              "elf2flt-cvs-${CT_ELF2FLT_VERSION}"
}

# Extract elf2flt
do_elf2flt_extract() {
    CT_Extract "elf2flt-cvs-${CT_ELF2FLT_VERSION}"
    CT_Patch "elf2flt-cvs" "${CT_ELF2FLT_VERSION}"
}

# Build elf2flt
do_elf2flt() {
    mkdir -p "${CT_BUILD_DIR}/build-elf2flt"
    cd "${CT_BUILD_DIR}/build-elf2flt"

    CT_DoStep INFO "Installing elf2flt"

    elf2flt_opts=
    binutils_bld=${CT_BUILD_DIR}/build-binutils
    binutils_src=${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}

    CT_DoLog EXTRA "Configuring elf2flt"
    CT_DoExecLog CFG                                            \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                              \
    "${CT_SRC_DIR}/elf2flt-cvs-${CT_ELF2FLT_VERSION}/configure" \
        --build=${CT_BUILD}                                     \
        --host=${CT_HOST}                                       \
        --target=${CT_TARGET}                                   \
        --prefix=${CT_PREFIX_DIR}                               \
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
                ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_BUILDTOOLS_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
                ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_BUILDTOOLS_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
            done 2>&1 |CT_DoLog ALL
            ;;
        *)  ;;
    esac

    CT_EndStep
}

fi # CT_ARCH_BINFMT_FLAT
