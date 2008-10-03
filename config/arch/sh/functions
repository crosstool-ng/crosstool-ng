# Compute sh-specific values

CT_DoArchValues () {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH_SH_VARIANT}${target_endian_eb}"

    # gcc ./configure flags
    CT_ARCH_WITH_ARCH=
    CT_ARCH_WITH_ABI=
    CT_ARCH_WITH_CPU=
    CT_ARCH_WITH_TUNE=
    CT_ARCH_WITH_FPU=
    CT_ARCH_WITH_FLOAT=

    # Endianness stuff
    case "${CT_ARCH_BE},${CT_ARCH_LE}" in
        y,) CT_ARCH_ENDIAN_CFLAG=-mb;;
        ,y) CT_ARCH_ENDIAN_CFLAG=-ml;;
    esac

    # CFLAGS
    case "${CT_ARCH_SH_VARIENT}" in
        sh3)    CT_ARCH_ARCH_CFLAG=-m3;;
        sh4*)
            case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
                y,) CT_ARCH_ARCH_CFLAG="-m4${CT_ARCH_SH_VARIANT##sh?}";;
                ,y) CT_ARCH_ARCH_CFLAG="-m4${CT_ARCH_SH_VARIANT##sh?}-nofpu";;
            esac
            ;;
    esac
    CT_ARCH_FLOAT_CFLAG=
}
