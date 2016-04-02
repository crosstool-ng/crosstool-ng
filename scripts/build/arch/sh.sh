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
