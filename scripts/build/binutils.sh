# This file adds functions to build binutils
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download binutils
do_binutils_get() {
    CT_GetFile "${CT_BINUTILS_FILE}"                                                    \
               {ftp,http}://{ftp.gnu.org/gnu,ftp.kernel.org/pub/linux/devel}/binutils   \
               ftp://gcc.gnu.org/pub/binutils/{releases,snapshots}
}

# Extract binutils
do_binutils_extract() {
    CT_ExtractAndPatch "${CT_BINUTILS_FILE}"
}

# Build binutils
do_binutils() {
    mkdir -p "${CT_BUILD_DIR}/build-binutils"
    cd "${CT_BUILD_DIR}/build-binutils"

    CT_DoStep INFO "Installing binutils"

    binutils_opts=
    # If GMP and MPFR were configured, then use that,
    # otherwise let binutils find the system-wide libraries, if they exist.
    if [ "${CT_GMP_MPFR}" = "y" ]; then
        binutils_opts="--with-gmp=${CT_PREFIX_DIR} --with-mpfr=${CT_PREFIX_DIR}"
    fi

    CT_DoLog EXTRA "Configuring binutils"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CT_DoExecLog ALL                                \
    "${CT_SRC_DIR}/${CT_BINUTILS_FILE}/configure"   \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix=${CT_PREFIX_DIR}                   \
        --disable-nls                               \
        --disable-multilib                          \
        --disable-werror                            \
        ${binutils_opts}                            \
        ${CT_ARCH_WITH_FLOAT}                       \
        ${CT_BINUTILS_EXTRA_CONFIG}                 \
        ${BINUTILS_SYSROOT_ARG}

    CT_DoLog EXTRA "Building binutils"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    CT_DoLog EXTRA "Installing binutils"
    CT_DoExecLog ALL make install

    # Make those new tools available to the core C compilers to come.
    # Note: some components want the ${TARGET}-{ar,as,ld,strip} commands as
    # well. Create that.
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/bin"
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/bin"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/bin"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/bin"
    for t in ar as ld strip; do
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_STATIC_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_SHARED_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
    done 2>&1 |CT_DoLog ALL

    CT_EndStep
}

# Now on for the target libraries
do_binutils_target() {
    targets=
    [ "${CT_BINUTILS_FOR_TARGET_IBERTY}" = "y" ] && targets="${targets} libiberty"
    [ "${CT_BINUTILS_FOR_TARGET_BFD}"    = "y" ] && targets="${targets} bfd"
    targets="${targets# }"

    binutils_opts=
    # If GMP and MPFR were configured, then use that
    if [ "${CT_GMP_MPFR_TARGET}" = "y" ]; then
        binutils_opts="--with-gmp=${CT_SYSROOT_DIR}/usr --with-mpfr=${CT_SYSROOT_DIR}/usr"
    fi

    if [ -n "${targets}" ]; then
        CT_DoStep INFO "Installing binutils for target"
        mkdir -p "${CT_BUILD_DIR}/build-binutils-for-target"
        CT_Pushd "${CT_BUILD_DIR}/build-binutils-for-target"

        CT_DoLog EXTRA "Configuring binutils for target"
        CT_DoExecLog ALL                                \
        "${CT_SRC_DIR}/${CT_BINUTILS_FILE}/configure"   \
            --build=${CT_BUILD}                         \
            --host=${CT_TARGET}                         \
            --target=${CT_TARGET}                       \
            --prefix=/usr                               \
            --disable-werror                            \
            --enable-shared                             \
            --enable-static                             \
            --disable-nls                               \
            --disable-multilib                          \
            ${binutils_opts}                            \
            ${CT_ARCH_WITH_FLOAT}                       \
            ${CT_BINUTILS_EXTRA_CONFIG}

        build_targets=$(echo "${targets}" |sed -r -e 's/(^| +)/\1all-/g;')
        install_targets=$(echo "${targets}" |sed -r -e 's/(^| +)/\1install-/g;')

        CT_DoLog EXTRA "Building binutils' libraries (${targets}) for target"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} ${build_targets}
        CT_DoLog EXTRA "Installing binutils' libraries (${targets}) for target"
        CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" ${install_targets}

        CT_Popd
        CT_EndStep
    fi
}
