# Compute s390-specific values

CT_DoArchTupleValues() {
    # That's the only thing to override
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="s390x${CT_ARCH_SUFFIX}"
    fi
}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "multilib flags" "target tuple"
CT_DoArchMultilibTarget ()
{
    local multi_flags="${1}"
    local target="${2}"
    local -ah

    local m31=false
    local m64=false

    case "${multi_flags}" in
        *-m64*) m64=true ;;
        *-m31*) m31=true ;;
    esac

    echo "${target}"
}
