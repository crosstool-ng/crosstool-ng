# Compute Alpha-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${CT_ARCH_ALPHA_VARIANT}}"
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
