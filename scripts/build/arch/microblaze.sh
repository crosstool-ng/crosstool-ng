# Compute microblaze specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${target_endian_el}}"

    # gcc ./configure flags
    CT_ARCH_WITH_ARCH=
    CT_ARCH_WITH_ABI=
    CT_ARCH_WITH_CPU=
    CT_ARCH_WITH_TUNE=
    CT_ARCH_WITH_FPU=
    CT_ARCH_WITH_FLOAT=

    # CFLAGS
    case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
        y,) CT_ARCH_FLOAT_CFLAG="-mhard-float" ;;
        ,y) CT_ARCH_FLOAT_CFLAG="-msoft-float" ;;
    esac

}
