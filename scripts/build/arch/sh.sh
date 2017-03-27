# Compute sh-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH_SH_VARIANT}${CT_ARCH_SUFFIX:-${target_endian_eb}}"

    # gcc ./configure flags
    CT_ARCH_WITH_ARCH=
    CT_ARCH_WITH_ABI=
    CT_ARCH_WITH_CPU=
    CT_ARCH_WITH_TUNE=
    CT_ARCH_WITH_FPU=
    CT_ARCH_WITH_FLOAT=

    # Endianness stuff
    case "${CT_ARCH_ENDIAN}" in
        big)    CT_ARCH_ENDIAN_CFLAG=-mb;;
        little) CT_ARCH_ENDIAN_CFLAG=-ml;;
    esac

    # CFLAGS
    case "${CT_ARCH_SH_VARIANT}" in
        sh3)    CT_ARCH_ARCH_CFLAG=-m3;;
        sh4*)
            # softfp is not possible for SuperH, no need to test for it.
            case "${CT_ARCH_FLOAT}" in
                hard)
                    CT_ARCH_ARCH_CFLAG="-m4${CT_ARCH_SH_VARIANT##sh?}"
                    ;;
                soft)
                    CT_ARCH_ARCH_CFLAG="-m4${CT_ARCH_SH_VARIANT##sh?}-nofpu"
                    ;;
            esac
            ;;
    esac
    CT_ARCH_FLOAT_CFLAG=
}

CT_DoArchMultilibList() {
    local save_ifs="${IFS}"
    local new
    local x

    # In a configuration for SuperH, GCC list of multilibs shall not include
    # the default CPU. E.g. if configuring for sh4-*-*, we need to remove
    # "sh4" or "m4" from the multilib list. Otherwise, the resulting compiler
    # will fail when that CPU is selected explicitly "sh4-multilib-linux-gnu-gcc -m4 ..."
    # as it will fail to find the sysroot with that suffix.
    IFS=,
    for x in ${CT_CC_GCC_MULTILIB_LIST}; do
        if [ "${x}" = "${CT_ARCH_SH_VARIANT}" -o "sh${x#m}" = "${CT_ARCH_SH_VARIANT}" ]; then
            CT_DoLog WARN "Ignoring '${x}' in multilib list: it is the default multilib"
            continue
        fi
        new="${new:+${new},}${x}"
    done
    IFS="${save_ifs}"
    CT_CC_GCC_MULTILIB_LIST="${new}"
    CT_DoLog DEBUG "Adjusted CT_CC_GCC_MULTILIB_LIST to '${CT_CC_GCC_MULTILIB_LIST}'"
}

CT_DoArchUClibcConfig() {
    local cfg="${1}"

    # FIXME: uclibc (!ng) seems to support sh64 (sh5), too
    CT_DoArchUClibcSelectArch "${cfg}" "sh"
    CT_KconfigDisableOption "CONFIG_SH3" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH4" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH4A" "${cfg}"
    case "${CT_ARCH_SH_VARIANT}" in
        sh3) CT_KconfigEnableOption "CONFIG_SH3" "${cfg}";;
        sh4) CT_KconfigEnableOption "CONFIG_SH4" "${cfg}";;
        sh4a) CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}";;
    esac
}

CT_DoArchUClibcCflags() {
    local cfg="${1}"
    local cflags="${2}"
    local f

    for f in ${cflags}; do
        case "${f}" in
            -m3)
                CT_KconfigEnableOption "CONFIG_SH3" "${cfg}"
                ;;
            -m4)
                CT_KconfigEnableOption "CONFIG_SH4" "${cfg}"
                CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m4-nofpu)
                CT_KconfigEnableOption "CONFIG_SH4" "${cfg}"
                CT_KconfigDisableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m4a)
                CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}"
                CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m4a-nofpu)
                CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}"
                CT_KconfigDisableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
        esac
    done
}
