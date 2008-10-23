# Compute IA-64-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${target_endian_el}"

    # Override CFLAGS for endianness:
    case "${CT_ARCH_BE},${CT_ARCH_LE}" in
        y,) CT_ARCH_ENDIAN_CFLAG="-EB";;
        ,y) CT_ARCH_ENDIAN_CFLAG="-EL";;
    esac
}
