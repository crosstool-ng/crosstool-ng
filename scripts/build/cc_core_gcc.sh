# This file adds the function to build the core gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download core gcc
do_cc_core_get() {
    # Ah! gcc folks are kind of 'different': they store the tarballs in
    # subdirectories of the same name! That's because gcc is such /crap/ that
    # it is such /big/ that it needs being splitted for distribution! Sad. :-(
    # Arrgghh! Some of those versions does not follow this convention:
    # gcc-3.3.3 lives in releases/gcc-3.3.3, while gcc-2.95.* isn't in a
    # subdirectory! You bastard!
    CT_GetFile "${CT_CC_CORE_FILE}"                                    \
               ftp://ftp.gnu.org/gnu/gcc/${CT_CC_CORE_FILE}            \
               ftp://ftp.gnu.org/gnu/gcc/releases/${CT_CC_CORE_FILE}   \
               ftp://ftp.gnu.org/gnu/gcc
}

# Extract core gcc
do_cc_core_extract() {
    CT_ExtractAndPatch "${CT_CC_CORE_FILE}"
}

# Build core gcc
do_cc_core() {
    mkdir -p "${CT_BUILD_DIR}/build-cc-core"
    cd "${CT_BUILD_DIR}/build-cc-core"

    CT_DoStep INFO "Installing core C compiler"

    CT_DoLog EXTRA "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
    mkdir -p "${CT_CC_CORE_PREFIX_DIR}/${CT_TARGET}/include"
    cp -r "${CT_HEADERS_DIR}"/* "${CT_CC_CORE_PREFIX_DIR}/${CT_TARGET}/include" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Configuring core C compiler"

    extra_config=""
    [ "${CT_ARCH_FLOAT_SW}" = "y" ] && extra_config="${extra_config} --with-float=soft"
    [ -n "${CT_ARCH_ABI}" ]  && extra_config="${extra_config} --with-abi=${CT_ARCH_ABI}"
    [ -n "${CT_ARCH_CPU}" ]  && extra_config="${extra_config} --with-cpu=${CT_ARCH_CPU}"
    [ -n "${CT_ARCH_TUNE}" ] && extra_config="${extra_config} --with-tune=${CT_ARCH_TUNE}"
    [ -n "${CT_ARCH_ARCH}" ] && extra_config="${extra_config} --with-arch=${CT_ARCH_ARCH}"
    [ -n "${CT_ARCH_FPU}" ] && extra_config="${extra_config} --with-fpu=${CT_ARCH_FPU}"
    [ "${CT_CC_CXA_ATEXIT}" == "y" ] && extra_config="${extra_config} --enable-__cxa_atexit"

    CT_DoLog DEBUG "Extra config passed: \"${extra_config}\""

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532)
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/configure"    \
        ${CT_CANADIAN_OPT}                          \
        --target=${CT_TARGET}                       \
        --host=${CT_HOST}                           \
        --prefix="${CT_CC_CORE_PREFIX_DIR}"         \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-multilib                          \
        --with-newlib                               \
        ${CC_CORE_SYSROOT_ARG}                      \
        ${extra_config}                             \
        --disable-nls                               \
        --enable-threads=no                         \
        --enable-symvers=gnu                        \
        --enable-languages=c                        \
        --disable-shared                            \
        ${CT_CC_CORE_EXTRA_CONFIG}                  2>&1 |CT_DoLog ALL

    if [ ! "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        make ${PARALLELMFLAGS} all-build-libiberty 2>&1 |CT_DoLog ALL
    fi

    CT_DoLog EXTRA "Building core C compiler"
    make ${PARALLELMFLAGS} all-gcc 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing core C compiler"
    make install-gcc 2>&1 |CT_DoLog ALL

    CT_EndStep
}

