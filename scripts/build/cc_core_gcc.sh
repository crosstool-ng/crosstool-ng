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

# Core gcc pass 1
do_cc_core_pass_1() {
    # In case we're NPTL, build the static core gcc;
    # in any other case, do nothing.
    case "${CT_THREADS}" in
        nptl)   do_cc_core_static;;
        *)      ;;
    esac
}

# Core gcc pass 2
do_cc_core_pass_2() {
    # In case we're NPTL, build the shared core gcc,
    # in any other case, build the static core gcc.
    case "${CT_THREADS}" in
        nptl)   do_cc_core_shared;;
        *)      do_cc_core_static;;
    esac
}

# Build static core gcc
do_cc_core_static() {
    mkdir -p "${CT_BUILD_DIR}/build-cc-core-static"
    cd "${CT_BUILD_DIR}/build-cc-core-static"

    CT_DoStep INFO "Installing static core C compiler"

    CT_DoLog EXTRA "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/include"
    cp -r "${CT_HEADERS_DIR}"/* "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/include" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Configuring static core C compiler"

    extra_config=""
    [ "${CT_ARCH_FLOAT_SW}" = "y" ] && extra_config="${extra_config} --with-float=soft"
    [ -n "${CT_ARCH_ABI}" ]  && extra_config="${extra_config} --with-abi=${CT_ARCH_ABI}"
    [ -n "${CT_ARCH_ARCH}" ] && extra_config="${extra_config} --with-arch=${CT_ARCH_ARCH}"
    [ -n "${CT_ARCH_CPU}" ]  && extra_config="${extra_config} --with-cpu=${CT_ARCH_CPU}"
    [ -n "${CT_ARCH_TUNE}" ] && extra_config="${extra_config} --with-tune=${CT_ARCH_TUNE}"
    [ -n "${CT_ARCH_FPU}" ] && extra_config="${extra_config} --with-fpu=${CT_ARCH_FPU}"
    [ "${CT_CC_CXA_ATEXIT}" = "y" ] && extra_config="${extra_config} --enable-__cxa_atexit"

    CT_DoLog DEBUG "Extra config passed: \"${extra_config}\""

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532)
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/configure"    \
        ${CT_CANADIAN_OPT}                          \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix="${CT_CC_CORE_STATIC_PREFIX_DIR}"  \
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

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        make ${PARALLELMFLAGS} all-build-libiberty 2>&1 |CT_DoLog ALL
    fi

    CT_DoLog EXTRA "Building static core C compiler"
    make ${PARALLELMFLAGS} all-gcc 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing static core C compiler"
    make install-gcc 2>&1 |CT_DoLog ALL

    CT_EndStep
}

# Build shared core gcc
do_cc_core_shared() {
    mkdir -p "${CT_BUILD_DIR}/build-cc-core-shared"
    cd "${CT_BUILD_DIR}/build-cc-core-shared"

    CT_DoStep INFO "Installing shared core C compiler"

    CT_DoLog EXTRA "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/include"
    cp -r "${CT_HEADERS_DIR}"/* "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/include" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Configuring shared core C compiler"

    extra_config=""
    [ "${CT_ARCH_FLOAT_SW}" = "y" ] && extra_config="${extra_config} --with-float=soft"
    [ -n "${CT_ARCH_ABI}" ]  && extra_config="${extra_config} --with-abi=${CT_ARCH_ABI}"
    [ -n "${CT_ARCH_ARCH}" ] && extra_config="${extra_config} --with-arch=${CT_ARCH_ARCH}"
    [ -n "${CT_ARCH_CPU}" ]  && extra_config="${extra_config} --with-cpu=${CT_ARCH_CPU}"
    [ -n "${CT_ARCH_TUNE}" ] && extra_config="${extra_config} --with-tune=${CT_ARCH_TUNE}"
    [ -n "${CT_ARCH_FPU}" ] && extra_config="${extra_config} --with-fpu=${CT_ARCH_FPU}"
    [ "${CT_CC_CXA_ATEXIT}" = "y" ] && extra_config="${extra_config} --enable-__cxa_atexit"

    CT_DoLog DEBUG "Extra config passed: \"${extra_config}\""

    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/configure"    \
        ${CT_CANADIAN_OPT}                          \
        --target=${CT_TARGET}                       \
        --host=${CT_HOST}                           \
        --prefix="${CT_CC_CORE_SHARED_PREFIX_DIR}"  \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-multilib                          \
        ${CC_CORE_SYSROOT_ARG}                      \
        ${extra_config}                             \
        --disable-nls                               \
        --enable-symvers=gnu                        \
        --enable-languages=c                        \
        --enable-shared                             \
        ${CT_CC_CORE_EXTRA_CONFIG}                  2>&1 |CT_DoLog ALL

    # HACK: we need to override SHLIB_LC from gcc/config/t-slibgcc-elf-ver or
    # gcc/config/t-libunwind so -lc is removed from the link for
    # libgcc_s.so, as we do not have a target -lc yet.
    # This is not as ugly as it appears to be ;-) All symbols get resolved
    # during the glibc build, and we provide a proper libgcc_s.so for the
    # cross toolchain during the final gcc build.
    #
    # As we cannot modify the source tree, nor override SHLIB_LC itself
    # during configure or make, we have to edit the resultant
    # gcc/libgcc.mk itself to remove -lc from the link.
    # This causes us to have to jump through some hoops...
    #
    # To produce libgcc.mk to edit we firstly require libiberty.a,
    # so we configure then build it.
    # Next we have to configure gcc, create libgcc.mk then edit it...
    # So much easier if we just edit the source tree, but hey...
    if [ ! -f "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/gcc/BASE-VER" ]; then
        make configure-libiberty
        make -C libiberty libiberty.a
        make configure-gcc
        make configure-libcpp
        make all-libcpp
    else
        make configure-gcc
        make configure-libcpp
        make configure-build-libiberty
        make all-libcpp
        make all-build-libiberty
    fi 2>&1 |CT_DoLog ALL
    # HACK: gcc-4.2 uses libdecnumber to build libgcc.mk, so build it here.
    if [ -d "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/libdecnumber" ]; then
        make configure-libdecnumber
        make -C libdecnumber libdecnumber.a
    fi 2>&1 |CT_DoLog ALL
    make -C gcc libgcc.mk 2>&1 |CT_DoLog ALL
    sed -r -i -e 's@-lc@@g' gcc/libgcc.mk

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        make ${PARALLELMFLAGS} all-build-libiberty 2>&1 |CT_DoLog ALL
    fi

    CT_DoLog EXTRA "Building shared core C compiler"
    make ${PARALLELMFLAGS} all-gcc 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing shared core C compiler"
    make install-gcc 2>&1 |CT_DoLog ALL

    CT_EndStep
}
