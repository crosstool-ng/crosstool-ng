# This file declares functions to install the kernel headers for linux
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() {
    [ "${CT_KERNEL}" = "linux" ] || return 0
    case "${CT_KERNEL_LINUX_HEADERS_SANITISED}" in
        y)  echo "linux-libc-headers-${CT_KERNEL_VERSION}";;
        *)  echo "linux-${CT_KERNEL_VERSION}";;
    esac
}

# Download the kernel
do_kernel_get() {
    if [ "${CT_KERNEL_LINUX_HEADERS_USE_CUSTOM_DIR}" != "y" ]; then
        CT_GetFile "${CT_KERNEL_FILE}"                                                  \
                   {ftp,http}://ftp.kernel.org/pub/linux/kernel/v2.{6{,/testing},4,2}   \
                   http://ep09.pld-linux.org/~mmazur/linux-libc-headers
    fi
    return 0
}

# Extract kernel
do_kernel_extract() {
    if [ "${CT_KERNEL_LINUX_HEADERS_USE_CUSTOM_DIR}" != "y" ]; then
        CT_ExtractAndPatch "${CT_KERNEL_FILE}"
    fi
    return 0
}

# Check kernel configuration
do_kernel_check_config() {
    # Only the copied or sanitised headers need a config file.
    # Pre-existing headers as well as headers_install don't.
    if [ "${CT_KERNEL_LINUX_NEEDS_CONFIG}" = "y"        \
         -a \( -z "${CT_KERNEL_LINUX_CONFIG_FILE}"      \
               -o ! -r "${CT_KERNEL_LINUX_CONFIG_FILE}" \
            \)                                          \
       ]; then
        CT_DoLog WARN "You did not provide a kernel configuration file!"
        CT_DoLog WARN "I will try to generate one for you, but beware!"

        CT_DoStep INFO "Building a default configuration file for linux kernel"

        mkdir -p "${CT_BUILD_DIR}/build-kernel-defconfig"
        cd "${CT_BUILD_DIR}/build-kernel-defconfig"
        make -C "${CT_SRC_DIR}/${CT_KERNEL_FILE}" O=`pwd`   \
             ARCH=${CT_KERNEL_ARCH} defconfig               2>&1 |CT_DoLog ALL

        CT_KERNEL_LINUX_CONFIG_FILE="`pwd`/.config"

        CT_EndStep
    fi
}

# Wrapper to the actual headers install method
do_kernel_headers() {
    CT_DoStep INFO "Installing kernel headers"

    # Special case when using pre-installed headers
    if [ "${CT_KERNEL_LINUX_HEADERS_USE_CUSTOM_DIR}" = "y" ]; then
        do_kernel_preinstalled
    else
        # We need to enter this directory to find the kernel version strings
        cd "${CT_SRC_DIR}/${CT_KERNEL_FILE}"
        if [ "${CT_KERNEL_LINUX_HEADERS_SANITISED}" != "y" ]; then
            k_version=`awk '/^VERSION =/ { print $3 }' Makefile`
            k_patchlevel=`awk '/^PATCHLEVEL =/ { print $3 }' Makefile`
            k_sublevel=`awk '/^SUBLEVEL =/ { print $3 }' Makefile`
            k_extraversion=`awk '/^EXTRAVERSION =/ { print $3 }' Makefile`
        else
            k_version=`echo "${CT_KERNEL_VERSION}." |cut -d . -f 1`
            k_patchlevel=`echo "${CT_KERNEL_VERSION}." |cut -d . -f 2`
            k_sublevel=`echo "${CT_KERNEL_VERSION}." |cut -d . -f 3`
            k_extraversion=`echo "${CT_KERNEL_VERSION}." |cut -d . -f 4`
        fi

        case "${k_version}.${k_patchlevel}" in
            2.2|2.4|2.6) ;;
            *)  CT_Abort "Unsupported kernel version \"linux-${k_version}.${k_patchlevel}\".";;
        esac

        # Kernel version that support verbosity will use this, others will ignore it:
        V_OPT="V=${CT_KERNEL_LINUX_VERBOSE_LEVEL}"

        if [ "${CT_KERNEL_LINUX_HEADERS_INSTALL}" = "y" ]; then
            do_kernel_install
        elif [ "${CT_KERNEL_LINUX_HEADERS_SANITISED}" = "y" ]; then
            do_kernel_sanitised
        else [ "${CT_KERNEL_LINUX_HEADERS_COPY}" = "y" ];
            do_kernel_copy
        fi
    fi

    CT_EndStep
}

# Install kernel headers using headers_install from kernel sources.
do_kernel_install() {
    CT_DoLog DEBUG "Using kernel's headers_install"

    mkdir -p "${CT_BUILD_DIR}/build-kernel-headers"
    cd "${CT_BUILD_DIR}/build-kernel-headers"

    case "${k_version}.${k_patchlevel}" in
        2.6) [ ${k_sublevel} -ge 18 ] || CT_Abort "Kernel version >= 2.6.18 is needed to install kernel headers.";;
        *)   CT_Abort "Kernel version >= 2.6.18 is needed to install kernel headers.";;
    esac

    CT_DoLog EXTRA "Installing kernel headers"
    make -C "${CT_SRC_DIR}/${CT_KERNEL_FILE}"       \
         O="`pwd`"                                  \
         ARCH=${CT_KERNEL_ARCH}                     \
         INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"   \
         ${V_OPT}                                   \
         headers_install                            2>&1 |CT_DoLog ALL

    if [ "${CT_KERNEL_LINUX_HEADERS_INSTALL_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking installed headers"
        make -C "${CT_SRC_DIR}/${CT_KERNEL_FILE}"       \
             O="`pwd`"                                  \
             ARCH=${CT_KERNEL_ARCH}                     \
             INSTALL_HDR_PATH="${CT_SYSROOT_DIR}/usr"   \
             ${V_OPT}                                   \
             headers_check                              2>&1 |CT_DoLog ALL
        find "${CT_SYSROOT_DIR}" -type f -name '.check*' -exec rm {} \;
    fi
}

# Install kernel headers from oldish Mazur's sanitised headers.
do_kernel_sanitised() {
    CT_DoLog EXTRA "Copying sanitised headers"
    cd "${CT_SRC_DIR}/${CT_KERNEL_FILE}"
    cp -rv include/linux "${CT_HEADERS_DIR}" 2>&1 |CT_DoLog ALL
    cp -rv "include/asm-${CT_KERNEL_ARCH}" "${CT_HEADERS_DIR}/asm" 2>&1 |CT_DoLog ALL
}

# Install kernel headers by plain copy.
do_kernel_copy() {
    CT_DoLog DEBUG "Copying plain kernel headers"
    CT_DoLog WARN "You are using plain kernel headers. You really shouldn't do that."
    CT_DoLog WARN "You'd be better off by using installed headers (or sanitised headers)."

    # 2.2 and 2.4 don't support building out-of-tree. 2.6 does.
    CT_DoLog EXTRA "Preparing kernel headers"
    case "${k_version}.${k_patchlevel}" in
        2.2|2.4) cd "${CT_SRC_DIR}/${CT_KERNEL_FILE}"
                 cp "${CT_KERNEL_LINUX_CONFIG_FILE}" .config
                 CT_DoYes "" |make ARCH=${CT_KERNEL_ARCH} oldconfig
                 # 2.4 doesn't follow V=# for verbosity... :-(
                 make ARCH=${CT_KERNEL_ARCH} symlinks include/linux/version.h
                 ;;
        2.6)     mkdir -p "${CT_BUILD_DIR}/build-kernel-headers"
                 cd "${CT_BUILD_DIR}/build-kernel-headers"
                 cp "${CT_KERNEL_LINUX_CONFIG_FILE}" .config
                 CT_DoYes "" |make -C "${CT_SRC_DIR}/${CT_KERNEL_FILE}"         \
                                   O="`pwd`" ${V_OPT} ARCH=${CT_KERNEL_ARCH}    \
                                   oldconfig
                 case "${CT_KERNEL_ARCH}" in
                     sh*)        # sh does secret stuff in 'make prepare' that can't be
                                 # triggered separately, but happily, it doesn't use
                                 # target gcc, so we can use it.
                                 # Update: this fails on 2.6.11, as it installs
                                 # elfconfig.h, which requires target compiler :-(
                                 make ${PARALLELMFLAGS}                 \
                                      ARCH=${CT_KERNEL_ARCH} ${V_OPT}   \
                                      prepare include/linux/version.h
                                 ;;
                     arm*|cris*) make ${PARALLELMFLAGS}                 \
                                      ARCH=${CT_KERNEL_ARCH} ${V_OPT}       \
                                      include/asm include/linux/version.h   \
                                      include/asm-${CT_KERNEL_ARCH}/.arch
                                 ;;
                     mips*)      # for linux-2.6, 'make prepare' for mips doesn't 
                                 # actually create any symlinks.  Hope generic is ok.
                                 # Note that glibc ignores all -I flags passed in CFLAGS,
                                 # so you have to use -isystem.
                                 make ${PARALLELMFLAGS}                 \
                                      ARCH=${CT_KERNEL_ARCH} ${V_OPT}   \
                                      include/asm include/linux/version.h
                                 TARGET_CFLAGS="${TARGET_CFLAGS} -isystem ${LINUX_HEADER_DIR}/include/asm-mips/mach-generic"
                                 ;;
                     *)          make ${PARALLELMFLAGS}                 \
                                      ARCH=${CT_KERNEL_ARCH} ${V_OPT}   \
                                      include/asm include/linux/version.h
                                 ;;
                 esac
                 ;;
    esac 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Copying kernel headers"
    cp -rv include/asm-generic "${CT_HEADERS_DIR}/asm-generic" 2>&1 |CT_DoLog ALL
    cp -rv include/linux "${CT_HEADERS_DIR}" 2>&1 |CT_DoLog ALL
    cp -rv include/asm-${CT_KERNEL_ARCH} "${CT_HEADERS_DIR}/asm" 2>&1 |CT_DoLog ALL
}

# Use preinstalled headers (most probably by using make headers_install in a
# modified (read: customised) kernel tree). In this case, simply copy
# the headers in place
do_kernel_preinstalled() {
    CT_DoLog EXTRA "Copying preinstalled kernel headers"

    mkdir -p "${CT_SYSROOT_DIR}/usr"
    cd "${CT_KERNEL_LINUX_HEADERS_CUSTOM_DIR}"
    cp -rv include "${CT_SYSROOT_DIR}/usr" 2>&1 |CT_DoLog ALL
}
