# This file declares functions to install the kernel headers for linux
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

CT_DoKernelTupleValues() {
    if [ "${CT_ARCH_USE_MMU}" = "y" ]; then
        CT_TARGET_KERNEL="linux"
    else
    # Sometime, noMMU linux targets have a -uclinux tuple, while
    # sometime it's -linux. We currently have only one noMMU linux
    # target, and it uses -linux, so let's just use that. Time
    # to fix that later...
    #    CT_TARGET_KERNEL="uclinux"
        CT_TARGET_KERNEL="linux"
    fi
}

# Download the kernel
do_kernel_get() {
    local k_ver
    if [    "${CT_KERNEL_LINUX_INSTALL}" = "y"  \
         -a "${CT_KERNEL_LINUX_CUSTOM}" != "y"  \
       ]; then
        case "${CT_KERNEL_VERSION}" in
            ?*.?*.?*.?*)
                # 4-part version, we need only first three digits
                k_ver="${CT_KERNEL_VERSION%.*}"
                ;;
            *)  # 3-part version, use all of it
                k_ver="${CT_KERNEL_VERSION}"
                ;;
        esac
        CT_GetFile "linux-${CT_KERNEL_VERSION}" \
                   {ftp,http}://ftp.{de.,eu.,}kernel.org/pub/linux/kernel/v2.{6{,/testing,/longterm/v${k_ver}},4,2}
    fi
}

# Extract kernel
do_kernel_extract() {
    local tar_opt
    if [ "${CT_KERNEL_LINUX_INSTALL}" = "y" ]; then
        if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y" ]; then
            # We extract the custom linux tree into a directory with a
            # well-known name, and strip the leading directory component
            # of the extracted pathes. This is needed because we do not
            # know the value for this first component, because it is a
            # _custom_ tree.
            # Also, we have to protect from partial extraction using the
            # .extracting and .extracted locks (not using .patching and
            # .patched as we are *not* patching that kernel).

            if [ -e "${CT_SRC_DIR}/.linux-custom.extracted" ]; then
                CT_DoLog DEBUG "Custom linux kernel tree already extracted"
                return 0
            fi

            CT_TestAndAbort "Custom kernel tree partially extracted. Remove before resuming" -f "${CT_SRC_DIR}/.linux-custom.extracting"
            CT_DoExecLog DEBUG touch "${CT_SRC_DIR}/.linux-custom.extracting"
            CT_DoExecLog DEBUG mkdir "${CT_SRC_DIR}/linux-custom"

            case "${CT_KERNEL_LINUX_CUSTOM_TARBALL}" in
                *.tar.bz2)      tar_opt=-j;;
                *.tar.gz|*.tgz) tar_opt=-z;;
                *.tar)          ;;
                *)              CT_Abort "Don't know how to handle '${CT_KERNEL_LINUX_CUSTOM_TARBALL}': unknown extension";;
            esac
            CT_DoLog EXTRA "Extracting custom linux kernel"
            CT_DoExecLog ALL tar x -C "${CT_SRC_DIR}/linux-custom"      \
                                 --strip-components 1 -v ${tar_opt}     \
                                 -f "${CT_KERNEL_LINUX_CUSTOM_TARBALL}"

            CT_DoExecLog ALL mv -v "${CT_SRC_DIR}/.linux-custom.extracting" "${CT_SRC_DIR}/.linux-custom.extracted"
        else
            CT_Extract "linux-${CT_KERNEL_VERSION}"
            CT_Patch "linux" "${CT_KERNEL_VERSION}"
        fi
    fi
}

# Wrapper to the actual headers install method
do_kernel_headers() {
    CT_DoStep INFO "Installing kernel headers"

    if [ "${CT_KERNEL_LINUX_INSTALL}" = "y" ]; then
        do_kernel_install
    else
        do_kernel_custom
    fi

    CT_EndStep
}

# Install kernel headers using headers_install from kernel sources.
do_kernel_install() {
    local kernel_path

    CT_DoLog DEBUG "Using kernel's headers_install"

    mkdir -p "${CT_BUILD_DIR}/build-kernel-headers"

    kernel_path="${CT_SRC_DIR}/linux-${CT_KERNEL_VERSION}"
    if [ "${CT_KERNEL_LINUX_CUSTOM}" = "y" ]; then
        kernel_path="${CT_SRC_DIR}/linux-custom"
    fi
    V_OPT="V=${CT_KERNEL_LINUX_VERBOSE_LEVEL}"

    CT_DoLog EXTRA "Installing kernel headers"
    CT_DoExecLog ALL                                    \
    make -C "${kernel_path}"                            \
         O="${CT_BUILD_DIR}/build-kernel-headers"       \
         ARCH=${CT_ARCH}                                \
         INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"       \
         ${V_OPT}                                       \
         headers_install

    if [ "${CT_KERNEL_LINUX_INSTALL_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking installed headers"
        CT_DoExecLog ALL                                    \
        make -C "${kernel_path}"                            \
             O="${CT_BUILD_DIR}/build-kernel-headers"       \
             ARCH=${CT_ARCH}                                \
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
            *.tar.lzma) tar_opt=--lzma;;
        esac
        CT_DoExecLog ALL tar x ${tar_opt} -vf ${CT_KERNEL_LINUX_CUSTOM_PATH}
    else
        CT_DoExecLog ALL cp -rv "${CT_KERNEL_LINUX_CUSTOM_PATH}/include" .
    fi
}
