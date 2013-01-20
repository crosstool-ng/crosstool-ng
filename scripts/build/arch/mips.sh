# Compute MIPS-specific values

CT_DoArchTupleValues() {
    local _64

    # The architecture part of the tuple
    if [ "${CT_ARCH_64}" = "y" ]; then
        _64="64"
    fi
    CT_TARGET_ARCH="${CT_ARCH}${_64}${CT_ARCH_SUFFIX:-${target_endian_el}}"

    # Override CFLAGS for endianness:
    case "${CT_ARCH_ENDIAN}" in
        big)    CT_ARCH_ENDIAN_CFLAG="-EB";;
        little) CT_ARCH_ENDIAN_CFLAG="-EL";;
    esac

    # Override ABI flags
    CT_ARCH_ABI_CFLAG="-mabi=${CT_ARCH_mips_ABI}"
    CT_ARCH_WITH_ABI="--with-abi=${CT_ARCH_mips_ABI}"
}
