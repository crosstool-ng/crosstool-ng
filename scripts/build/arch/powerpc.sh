# Compute powerpc-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple, override only for 64-bit
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="powerpc64${CT_ARCH_SUFFIX}"
    fi

    # Only override values when ABI is not the default
    case "${CT_ARCH_powerpc_ABI}" in
        eabi)
            # EABI is only for bare-metal, so libc ∈ [none,newlib]
            CT_TARGET_SYS="eabi"
            ;;
        spe)
            case "${CT_LIBC}" in
                none|newlib)    CT_TARGET_SYS="spe";;
                *glibc)         CT_TARGET_SYS="gnuspe";;
                uClibc)         CT_TARGET_SYS="uclibcgnuspe";;
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
