# This file declares functions to install the kernel headers for linux
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

CT_DoKernelTupleValues() {
    if [ "${CT_ARCH_USE_MMU}" = "y" ]; then
        CT_TARGET_KERNEL="linux"
    else
        # Some no-mmu linux targets requires a -uclinux tuple (like m68k/cf),
        # while others must have a -linux tuple.  Other targets
        # should be added here when someone starts to care about them.
        case "${CT_ARCH}" in
            m68k)       CT_TARGET_KERNEL="uclinux" ;;
            *)          CT_Abort "Unsupported no-mmu arch '${CT_ARCH}'"
        esac
    fi
}

# Download the kernel
do_kernel_get() {
    local k_ver
    local custom_name
    local rel_dir
    local korg_base mirror_base

    if [ "${CT_KERNEL_LINUX_USE_CUSTOM_HEADERS}" = "y"  ]; then
        return 0
    fi

    if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y" ]; then
        CT_GetCustom "linux" "${CT_KERNEL_VERSION}"     \
                     "${CT_KERNEL_LINUX_CUSTOM_LOCATION}"
    else # Not a custom tarball
        case "${CT_KERNEL_VERSION}" in
            2.6.*.*|3.*.*|4.*.*)
                # 4-part versions (for 2.6 stables and long-terms), and
                # 3-part versions (for 3.x.y and 4.x.y stables and long-terms)
                # we need to trash the last digit
                k_ver="${CT_KERNEL_VERSION%.*}"
                ;;
            2.6.*|3.*|4.*)
                # 3-part version (for 2.6.x initial releases), and 2-part
                # versions (for 3.x and 4.x initial releases), use all of it
                k_ver="${CT_KERNEL_VERSION}"
                ;;
        esac
        case "${CT_KERNEL_VERSION}" in
            2.6.*)  rel_dir=v2.6;;
            3.*)    rel_dir=v3.x;;
            4.*)    rel_dir=v4.x;;
        esac
        korg_base="http://www.kernel.org/pub/linux/kernel/${rel_dir}"
        CT_GetFile "linux-${CT_KERNEL_VERSION}"         \
                   "${korg_base}"                       \
                   "${korg_base}/longterm/v${k_ver}"    \
                   "${korg_base}/longterm"
    fi
}

# Extract kernel
do_kernel_extract() {
    # If using a custom headers tree, nothing to do
    if [ "${CT_KERNEL_LINUX_USE_CUSTOM_HEADERS}" = "y" ]; then
        return 0
    fi

    # If using a custom directory location, nothing to do
    if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y"    \
         -a -d "${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}" ]; then
        return 0
    fi

    # Otherwise, we're using either a mainstream tarball, or a custom
    # tarball; in either case, we need to extract
    CT_Extract "linux-${CT_KERNEL_VERSION}"

    # If using a custom tarball, no need to patch
    if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y" ]; then
        return 0
    fi
    CT_Patch "linux" "${CT_KERNEL_VERSION}"
}

# Wrapper to the actual headers install method
do_kernel_headers() {
    CT_DoStep INFO "Installing kernel headers"

    if [ "${CT_KERNEL_LINUX_USE_CUSTOM_HEADERS}" = "y" ]; then
        do_kernel_custom
    else
        do_kernel_install
    fi

    CT_EndStep
}

# Install kernel headers using headers_install from kernel sources.
do_kernel_install() {
    local kernel_path
    local kernel_arch

    CT_DoLog DEBUG "Using kernel's headers_install"

    mkdir -p "${CT_BUILD_DIR}/build-kernel-headers"

    kernel_path="${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}"
    if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y" ]; then
        kernel_path="${CT_SRC_DIR}/linux-custom"
    fi
    V_OPT="V=${CT_KERNEL_LINUX_VERBOSE_LEVEL}"

    kernel_arch="${CT_ARCH}"
    case "${CT_ARCH}:${CT_ARCH_BITNESS}" in
        # ARM 64 (aka AArch64) is special
        arm:64) kernel_arch="arm64";;
    esac

    CT_DoLog EXTRA "Installing kernel headers"
    CT_DoExecLog ALL                                    \
    ${make} -C "${kernel_path}"                         \
         CROSS_COMPILE="${CT_TARGET}-"                  \
         O="${CT_BUILD_DIR}/build-kernel-headers"       \
         ARCH=${kernel_arch}                            \
         INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"       \
         ${V_OPT}                                       \
         headers_install

    if [ "${CT_KERNEL_LINUX_INSTALL_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking installed headers"
        CT_DoExecLog ALL                                    \
        ${make} -C "${kernel_path}"                         \
             CROSS_COMPILE="${CT_TARGET}-"                  \
             O="${CT_BUILD_DIR}/build-kernel-headers"       \
             ARCH=${kernel_arch}                            \
             INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"       \
             ${V_OPT}                                       \
             headers_check
    fi

    # Cleanup
    find "${CT_SYSROOT_DIR}" -type f                        \
                             \(    -name '.install'         \
                                -o -name '..install.cmd'    \
                                -o -name '.check'           \
                                -o -name '..check.cmd'      \
                             \)                             \
                             -exec rm {} \;
}

# Use custom headers (most probably by using make headers_install in a
# modified (read: customised) kernel tree, or using pre-2.6.18 headers, such
# as 2.4). In this case, simply copy the headers in place
do_kernel_custom() {
    local tar_opt

    CT_DoLog EXTRA "Installing custom kernel headers"

    mkdir -p "${CT_SYSROOT_DIR}/usr"
    cd "${CT_SYSROOT_DIR}/usr"
    if [ "${CT_KERNEL_LINUX_CUSTOM_IS_TARBALL}" = "y" ]; then
        case "${CT_KERNEL_LINUX_CUSTOM_PATH}" in
            *.tar)      ;;
            *.tgz)      tar_opt=--gzip;;
            *.tar.gz)   tar_opt=--gzip;;
            *.tar.bz2)  tar_opt=--bzip2;;
            *.tar.xz)   tar_opt=--xz;;
        esac
        CT_DoExecLog ALL tar x ${tar_opt} -vf ${CT_KERNEL_LINUX_CUSTOM_PATH}
    else
        CT_DoExecLog ALL cp -rv "${CT_KERNEL_LINUX_CUSTOM_PATH}/include" .
    fi
}
