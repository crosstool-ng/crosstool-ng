# Compute AVR32-specific values

CT_DoArchTupleValues() {
    # gcc ./configure flags
    CT_ARCH_WITH_ARCH=
    CT_ARCH_WITH_ABI=
    CT_ARCH_WITH_CPU=
    CT_ARCH_WITH_TUNE=
    CT_ARCH_WITH_FPU=
    CT_ARCH_WITH_FLOAT=
    CT_TARGET_SYS=none

}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "multilib flags" "target tuple"
CT_DoArchMultilibTarget ()
{
    local multi_flags="${1}"
    local target="${2}"

    :;

    echo "${target}"
}
