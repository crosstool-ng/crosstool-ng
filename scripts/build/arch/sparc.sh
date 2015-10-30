# Compute sparc-specific values
CT_DoArchTupleValues() {
    # That's the only thing to override
    CT_TARGET_ARCH="sparc${target_bits_64}${CT_ARCH_SUFFIX}"
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
