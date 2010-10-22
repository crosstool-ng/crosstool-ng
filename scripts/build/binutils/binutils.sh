# This file adds functions to build binutils
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download binutils
do_binutils_get() {
    CT_GetFile "binutils-${CT_BINUTILS_VERSION}"                                        \
               {ftp,http}://{ftp.gnu.org/gnu,ftp.kernel.org/pub/linux/devel}/binutils   \
               ftp://gcc.gnu.org/pub/binutils/{releases,snapshots}
}

# Extract binutils
do_binutils_extract() {
    CT_Extract "binutils-${CT_BINUTILS_VERSION}"
    CT_Patch "binutils" "${CT_BINUTILS_VERSION}"
}

# Build binutils
do_binutils() {
    local -a extra_config

    mkdir -p "${CT_BUILD_DIR}/build-binutils"
    cd "${CT_BUILD_DIR}/build-binutils"

    CT_DoStep INFO "Installing binutils"

    CT_DoLog EXTRA "Configuring binutils"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                              \
    CT_DoExecLog CFG                                            \
    "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
        --build=${CT_BUILD}                                     \
        --host=${CT_HOST}                                       \
        --target=${CT_TARGET}                                   \
        --prefix=${CT_PREFIX_DIR}                               \
        --disable-nls                                           \
        --disable-multilib                                      \
        --disable-werror                                        \
        "${extra_config[@]}"                                    \
        ${CT_ARCH_WITH_FLOAT}                                   \
        ${CT_BINUTILS_EXTRA_CONFIG}                             \
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
    local -a extra_config
    local -a targets
    local -a build_targets
    local -a install_targets
    local t

    [ "${CT_BINUTILS_FOR_TARGET_IBERTY}" = "y" ] && targets+=("libiberty")
    [ "${CT_BINUTILS_FOR_TARGET_BFD}"    = "y" ] && targets+=("bfd")
    for t in "${targets[@]}"; do
        build_targets+=("all-${t}")
        install_targets+=("install-${t}")
    done

    if [ "${#targets[@]}" -ne 0 ]; then
        CT_DoStep INFO "Installing binutils for target"
        mkdir -p "${CT_BUILD_DIR}/build-binutils-for-target"
        CT_Pushd "${CT_BUILD_DIR}/build-binutils-for-target"

        CT_DoLog EXTRA "Configuring binutils for target"
        CT_DoExecLog ALL                                            \
        "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
            --build=${CT_BUILD}                                     \
            --host=${CT_TARGET}                                     \
            --target=${CT_TARGET}                                   \
            --prefix=/usr                                           \
            --disable-werror                                        \
            --enable-shared                                         \
            --enable-static                                         \
            --disable-nls                                           \
            --disable-multilib                                      \
            "${extra_config[@]}"                                    \
            ${CT_ARCH_WITH_FLOAT}                                   \
            ${CT_BINUTILS_EXTRA_CONFIG}

        CT_DoLog EXTRA "Building binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} "${build_targets[@]}"
        CT_DoLog EXTRA "Installing binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" "${install_targets[@]}"

        CT_Popd
        CT_EndStep
    fi
}
