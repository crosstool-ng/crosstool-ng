# This file declares functions to install the kernel headers for linux
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

CT_DoKernelTupleValues() {
    if [ "${CT_ARCH_USE_MMU}" = "y" ]; then
        CT_TARGET_KERNEL="linux"
    else
        CT_TARGET_KERNEL="uclinux"
    fi
}

# Download the kernel
do_kernel_get() {
    if [ "${CT_KERNEL_LINUX_USE_CUSTOM_HEADERS}" != "y" ]; then
        CT_GetFile "linux-${CT_KERNEL_VERSION}" \
                   {ftp,http}://ftp.{de.,eu.,}kernel.org/pub/linux/kernel/v2.{6{,/testing},4,2}
    fi
    return 0
}

# Extract kernel
do_kernel_extract() {
    if [ "${CT_KERNEL_LINUX_USE_CUSTOM_HEADERS}" != "y" ]; then
        CT_Extract "linux-${CT_KERNEL_VERSION}"
        CT_Patch "linux-${CT_KERNEL_VERSION}"
    fi
    return 0
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
    CT_DoLog DEBUG "Using kernel's headers_install"

    mkdir -p "${CT_BUILD_DIR}/build-kernel-headers"
    cd "${CT_BUILD_DIR}/build-kernel-headers"

    # Only starting with 2.6.18 does headers_install is usable. We only
    # have 2.6 version available, so only test for sublevel.
    k_sublevel=$(awk '/^SUBLEVEL =/ { print $3 }' "${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}/Makefile")
    [ ${k_sublevel} -ge 18 ] || CT_Abort "Kernel version >= 2.6.18 is needed to install kernel headers."

    V_OPT="V=${CT_KERNEL_LINUX_VERBOSE_LEVEL}"

    CT_DoLog EXTRA "Installing kernel headers"
    CT_DoExecLog ALL                                    \
    make -C "${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}"  \
         O=$(pwd)                                       \
         ARCH=${CT_ARCH}                                \
         INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"       \
         ${V_OPT}                                       \
         headers_install

    if [ "${CT_KERNEL_LINUX_INSTALL_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking installed headers"
        CT_DoExecLog ALL                                    \
        make -C "${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}"  \
             O=$(pwd)                                       \
             ARCH=${CT_ARCH}                                \
             INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"       \
             ${V_OPT}                                       \
             headers_check
        find "${CT_SYSROOT_DIR}" -type f -name '.check*' -exec rm {} \;
    fi
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
            *.tar.lzma) tar_opt=--lzma;;
        esac
        CT_DoExecLog ALL tar x ${tar_opt} -vf ${CT_KERNEL_LINUX_CUSTOM_PATH}
    else
        CT_DoExecLog ALL cp -rv "${CT_KERNEL_LINUX_CUSTOM_PATH}/include" .
    fi
}
