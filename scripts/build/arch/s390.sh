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
    local target="${1}"; shift
    local -a multi_flags=( "$@" )

    local m31=false
    local m64=false

    for m in "${multi_flags[@]}"; do
        case "${multi_flags}" in
            -m64) m64=true ;;
            -m31) m31=true ;;
        esac
    done

    # Fix bitness
    case "${target}" in
        s390-*)   $m64 && target=${target/#s390-/s390x-} ;;
        s390x-*)  $m31 && target=${target/#s390x-/s390-} ;;
    esac

    echo "${target}"
}
