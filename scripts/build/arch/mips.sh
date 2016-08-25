# Compute MIPS-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple
    CT_TARGET_ARCH="${CT_ARCH}${target_bits_64}${CT_ARCH_SUFFIX:-${target_endian_el}}"

    # Override CFLAGS for endianness:
    case "${CT_ARCH_ENDIAN}" in
        big)    CT_ARCH_ENDIAN_CFLAG="-EB";;
        little) CT_ARCH_ENDIAN_CFLAG="-EL";;
    esac

    # Override ABI flags
    CT_ARCH_ABI_CFLAG="-mabi=${CT_ARCH_mips_ABI}"
    CT_ARCH_WITH_ABI="--with-abi=${CT_ARCH_mips_ABI}"
}

CT_DoArchUClibcConfig() {
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "${CT_ARCH}"

    CT_KconfigDisableOption "CONFIG_MIPS_O32_ABI" "${cfg}"
    CT_KconfigDisableOption "CONFIG_MIPS_N32_ABI" "${cfg}"
    CT_KconfigDisableOption "CONFIG_MIPS_N64_ABI" "${cfg}"
    case "${CT_ARCH_mips_ABI}" in
        32)
            CT_KconfigEnableOption "CONFIG_MIPS_O32_ABI" "${cfg}"
            ;;
        n32)
            CT_KconfigEnableOption "CONFIG_MIPS_N32_ABI" "${cfg}"
            ;;
        64)
            CT_KconfigEnableOption "CONFIG_MIPS_N64_ABI" "${cfg}"
            ;;
    esac

    # FIXME: uClibc (!ng) allows to select ISA in the config; should
    # match from the selected ARCH_ARCH level... For now, delete and
    # fall back to default.
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_1" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_2" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_3" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_4" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS32" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS32R2" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS64" "${cfg}"
    CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS64R2" "${cfg}"
}

CT_DoArchUClibcCflags() {
    local cfg="${1}"
    local cflags="${2}"
    local f

    for f in ${cflags}; do
        case "${f}" in
            -mabi=*)
                CT_KconfigDisableOption "CONFIG_MIPS_O32_ABI" "${cfg}"
                CT_KconfigDisableOption "CONFIG_MIPS_N32_ABI" "${cfg}"
                CT_KconfigDisableOption "CONFIG_MIPS_N64_ABI" "${cfg}"
                case "${f#-mabi=}" in
                    32)  CT_KconfigEnableOption "CONFIG_MIPS_O32_ABI" "${cfg}";;
                    n32) CT_KconfigEnableOption "CONFIG_MIPS_N32_ABI" "${cfg}";;
                    64)  CT_KconfigEnableOption "CONFIG_MIPS_N64_ABI" "${cfg}";;
                    *)   CT_Abort "Unsupported ABI: ${f#-mabi=}";;
                esac
                ;;
        esac
    done
}
