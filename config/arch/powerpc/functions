# Compute powerpc-specific values

CT_DoArchValues () {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}"

    # The kernel ARCH:
    CT_KERNEL_ARCH=powerpc

    # Add spe in the tuplet if needed
    case "${CT_LIBC},${CT_ARCH_POWERPC_SPE}" in
        glibc,|eglibc,)   CT_TARGET_SYS=gnu;;
        glibc,y|eglibc,y) CT_TARGET_SYS=gnuspe;;
    esac

    # Add extra flags for SPE if needed
    if [ "${CT_ARCH_POWERPC_SPE}" = "y" ]; then
        CT_ARCH_TARGET_CFLAGS="-mabi=spe -mspe"
        CT_ARCH_CC_CORE_EXTRA_CONFIG="--enable-e500_double"
        CT_ARCH_CC_EXTRA_CONFIG="--enable-e500_double"
    fi
}
