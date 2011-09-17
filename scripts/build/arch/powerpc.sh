# Compute powerpc-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple, override only for 64-bit
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="powerpc64"
    fi

    CT_TARGET_SYS="gnu"
    case "${CT_ARCH_powerpc_ABI}" in
        "") ;;
        eabi) CT_TARGET_SYS="eabi";;
        spe)
            case "${CT_LIBC}" in
                glibc|eglibc) CT_TARGET_SYS="gnuspe";;
                *)            CT_TARGET_SYS="spe";
            esac
            ;;
    esac

    # Add extra flags for SPE if needed
    if [ "${CT_ARCH_powerpc_ABI_SPE}" = "y" ]; then
        CT_ARCH_TARGET_CFLAGS="-mabi=spe -mspe"
        CT_ARCH_CC_CORE_EXTRA_CONFIG="--enable-e500_double"
        CT_ARCH_CC_EXTRA_CONFIG="--enable-e500_double"
    fi
}
