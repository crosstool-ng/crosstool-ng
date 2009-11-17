# Compute powerpc-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple, override only for 64-bit
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="powerpc64"
    fi

    # Add spe in the tuple if needed
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
