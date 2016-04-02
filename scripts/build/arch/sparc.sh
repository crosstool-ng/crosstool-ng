# Compute sparc-specific values
CT_DoArchTupleValues() {
    # That's the only thing to override
    CT_TARGET_ARCH="sparc${target_bits_64}${CT_ARCH_SUFFIX}"

    # By default, sparc64-*-linux is configured with -mcpu=v9. However,
    # according to https://sourceware.org/ml/libc-alpha/2005-12/msg00027.html,
    # "There is no Linux sparc64 port that runs on non-UltraSPARC-I+ ISA CPUs."
    # There is a patch that would change the default to -mcpu=ultrasparc for
    # sparc64-*-linux configuration: https://patchwork.ozlabs.org/patch/409424/
    # but that patch has not been integrated (yet). One concern raised about
    # this patch was that -mcpu=ultrasparc can suboptimally schedule instructions
    # for newer SPARC CPUs. So, override to -mcpu=ultrasparc and warn the user.
    if [ "${CT_KERNEL}" = "linux" -a "${CT_ARCH_64}" = "y" -a -z "${CT_ARCH_CPU}" ]; then
        CT_DoLog WARN "Setting CPU to UltraSPARC-I for sparc64-linux. Set CT_ARCH_CPU if a different CPU is desired."
        CT_ARCH_WITH_CPU="--with-cpu=ultrasparc"
    fi
}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "multilib flags" "target tuple"
CT_DoArchMultilibTarget ()
{
    local target="${1}"; shift
    local -a multi_flags=( "$@" )

    local m32=false
    local m64=false

    for m in "${multi_flags[@]}"; do
        case "$m" in
            -m32)     m32=true ;;
            -m64)     m64=true ;;
        esac
    done

    # Fix up bitness
    case "${target}" in
        sparc-*)      $m64 && target=${target/#sparc-/sparc64-} ;;
        sparc64-*)    $m32 && target=${target/#sparc64-/sparc-} ;;
    esac

    echo "${target}"
}

# Special tuple adjustment for glibc.
CT_DoArchGlibcAdjustTuple() {
    local target="${1}"

    case "${target}" in
        # SPARC quirk: glibc 2.23 and newer dropped support for SPARCv8 and
        # earlier (corresponding pthread barrier code is missing). Until this
        # support is reintroduced, configure as sparcv9.
        sparc-*)
            if [ "${CT_LIBC_GLIBC_2_23_or_later}" = y ]; then
                target=${target/#sparc-/sparcv9-}
            fi
            ;;
    esac

    echo "${target}"
}
