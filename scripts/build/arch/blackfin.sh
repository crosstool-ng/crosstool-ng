# Compute Blackfin-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="bfin${CT_ARCH_SUFFIX}"

    # gcc ./configure flags
    CT_ARCH_WITH_ARCH=
    CT_ARCH_WITH_ABI=
    CT_ARCH_WITH_CPU=
    CT_ARCH_WITH_TUNE=
    CT_ARCH_WITH_FPU=
    CT_ARCH_WITH_FLOAT=
}
