# Compute LoongArch-specific values

CT_DoArchTupleValues() {
    CT_TARGET_ARCH="loongarch${CT_ARCH_BITNESS}"

    case "${CT_ARCH_ABI}" in
        *lp*f)
            CT_TARGET_SYS="${CT_TARGET_SYS}f32"
            ;;
        *lp*s)
            CT_TARGET_SYS="${CT_TARGET_SYS}sf"
            ;;
    esac
}
