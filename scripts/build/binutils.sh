# This file adds functions to build binutils
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() {
    echo "binutils-${CT_BINUTILS_VERSION}"
}

# Download binutils
do_binutils_get() {
    CT_GetFile "${CT_BINUTILS_FILE}"                            \
               ftp://ftp.gnu.org/gnu/binutils                   \
               ftp://ftp.kernel.org/pub/linux/devel/binutils
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

    CT_DoLog EXTRA "Configuring binutils"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    "${CT_SRC_DIR}/${CT_BINUTILS_FILE}/configure"   \
        ${CT_CANADIAN_OPT}                          \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix=${CT_PREFIX_DIR}                   \
        --disable-nls                               \
        ${CT_BINUTILS_EXTRA_CONFIG}                 \
        ${BINUTILS_SYSROOT_ARG}                     2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Building binutils"
    make ${PARALLELMFLAGS}  2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing binutils"
    make install            2>&1 |CT_DoLog ALL

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
    done |CT_DoLog ALL

    CT_EndStep
}

# Now on for the target libraries
do_binutils_target() {
    targets=
    [ "${CT_BINUTILS_FOR_TARGET_IBERTY}" = "y" ] && targets="${targets} libiberty"
    [ "${CT_BINUTILS_FOR_TARGET_BFD}"    = "y" ] && targets="${targets} bfd"
    targets="${targets# }"

    if [ -n "${targets}" ]; then
        CT_DoStep INFO "Installing binutils for target"
        mkdir -p "${CT_BUILD_DIR}/build-binutils-for-target"
        CT_Pushd "${CT_BUILD_DIR}/build-binutils-for-target"

        CT_DoLog EXTRA "Configuring binutils for target"
        "${CT_SRC_DIR}/${CT_BINUTILS_FILE}/configure"       \
            --build=${CT_BUILD}                             \
            --host=${CT_TARGET}                             \
            --target=${CT_TARGET}                           \
            --prefix=/usr                                   \
            ${CT_BINUTILS_EXTRA_CONFIG}                     \
            --disable-nls                                   2>&1 |CT_DoLog ALL

        build_targets=$(echo "${targets}" |sed -r -e 's/(^| +)/\1all-/g;')
        install_targets=$(echo "${targets}" |sed -r -e 's/(^| +)/\1install-/g;')

        CT_DoLog EXTRA "Building binutils' libraries (${targets}) for target"
        make ${PARALLELMFLAGS} ${build_targets}  2>&1 |CT_DoLog ALL
        CT_DoLog EXTRA "Installing binutils' libraries (${targets}) for target"
        make DESTDIR="${CT_SYSROOT_DIR}" ${install_targets}  2>&1 |CT_DoLog ALL

        CT_Popd
        CT_EndStep
    fi
}
