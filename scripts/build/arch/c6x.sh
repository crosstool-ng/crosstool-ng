# Compute c6x-specific values

CT_DoArchUClibcConfig() {
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "c6x"
}

CT_DoArchTupleValues() {
    CT_TARGET_ARCH="tic6x"
    #binutils does not like uclibc in the tuple
    if [ "${CT_TARGET_SYS}" = "uclibc" ]; then
        CT_TARGET_SYS=
    fi
}

CT_DoArchUClibcHeaderDir() {
    local dir_var="${1}"
    local cflags="${2}"

    # If it is non-default multilib, add a suffix with architecture (reported by gcc)
    # to the headers installation path.
    if [ -n "${cflags}" ]; then
        eval "${dir_var}="$( ${CT_TARGET}-${CT_CC} -print-multiarch ${cflags} )
    fi
}

CT_DoArchUClibcCflags() {
    local cfg="${1}"
    local cflags="${2}"
    local f

    # Set default little endian options
    CT_KconfigDisableOption "ARCH_BIG_ENDIAN" "${cfg}"
    CT_KconfigDisableOption "ARCH_WANTS_BIG_ENDIAN" "${cfg}"
    CT_KconfigEnableOption "ARCH_LITTLE_ENDIAN" "${cfg}"
    CT_KconfigEnableOption "ARCH_WANTS_LITTLE_ENDIAN" "${cfg}"

    # Set arch options based on march switch
    CT_KconfigDisableOption "CONFIG_TMS320C674X" "${cfg}"
    CT_KconfigDisableOption "CONFIG_TMS320C64XPLUS" "${cfg}"
    CT_KconfigDisableOption "CONFIG_TMS320C64X" "${cfg}"
    CT_KconfigDisableOption "UCLIBC_HAS_FPU" "${cfg}"
    CT_KconfigEnableOption "CONFIG_GENERIC_C6X" "${cfg}"

    for f in ${cflags}; do
        case "${f}" in
            -march=*)
                case "${f#-march=}" in
                    c674x)  
                        CT_KconfigEnableOption "CONFIG_TMS320C674X" "${cfg}"
                        CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                        CT_KconfigDisableOption "CONFIG_GENERIC_C6X" "${cfg}"
                        ;;
                    c64x+) 
                        CT_KconfigEnableOption "CONFIG_TMS320C64XPLUS" "${cfg}"
                        CT_KconfigDisableOption "CONFIG_GENERIC_C6X" "${cfg}"
                        ;;
                    c64x)  
                        CT_KconfigEnableOption "CONFIG_TMS320C64X" "${cfg}"
                        CT_KconfigDisableOption "CONFIG_GENERIC_C6X" "${cfg}"
                        ;;
                    c67x)
                        CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                        ;;
                    c62x)
                        ;;
                    *)   CT_Abort "Unsupported architecture: ${f#-march=}";;
                esac
                ;;
            -mbig-endian)
                CT_KconfigEnableOption "ARCH_BIG_ENDIAN" "${cfg}"
                CT_KconfigEnableOption "ARCH_WANTS_BIG_ENDIAN" "${cfg}"
                CT_KconfigDisableOption "ARCH_LITTLE_ENDIAN" "${cfg}"
                CT_KconfigDisableOption "ARCH_WANTS_LITTLE_ENDIAN" "${cfg}"
                ;;
        esac
    done
}
