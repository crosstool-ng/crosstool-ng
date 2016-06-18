# Compute powerpc-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple
    CT_TARGET_ARCH="powerpc${target_bits_64}${target_endian_le}${CT_ARCH_SUFFIX}"

    # Only override values when ABI is not the default
    case "${CT_ARCH_powerpc_ABI}" in
        eabi)
            # EABI is only for bare-metal, so libc ∈ [none,newlib]
            CT_TARGET_SYS="eabi"
            ;;
        spe)
            case "${CT_LIBC}" in
                none|newlib)    CT_TARGET_SYS="spe";;
                *glibc)         CT_TARGET_SYS="gnuspe";;
                uClibc)         CT_TARGET_SYS="uclibcgnuspe";;
            esac
            ;;
    esac

    # Add extra flags for SPE if needed
    if [ "${CT_ARCH_powerpc_ABI_SPE}" = "y" ]; then
        CT_ARCH_TARGET_CFLAGS="-mabi=spe -mspe"
        CT_ARCH_CC_CORE_EXTRA_CONFIG="--enable-e500_double"
        CT_ARCH_CC_EXTRA_CONFIG="--enable-e500_double"
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
    local mlittle=false
    local mbig=false

    for m in "${multi_flags[@]}"; do
        case "$m" in
            -m32)     m32=true ;;
            -m64)     m64=true ;;
            -mbig)    mbig=true ;;
            -mlittle) mlittle=true ;;
        esac
    done

    # Fix up bitness
    case "${target}" in
        powerpc-*)      $m64 && target=${target/#powerpc-/powerpc64-} ;;
        powerpcle-*)    $m64 && target=${target/#powerpcle-/powerpc64le-} ;;
        powerpc64-*)    $m32 && target=${target/#powerpc64-/powerpc-} ;;
        powerpc64le-*)  $m32 && target=${target/#powerpc64le-/powerpcle-} ;;
    esac

    # Fix up endianness
    case "${target}" in
        powerpc-*)      $mlittle && target=${target/#powerpc-/powerpcle-} ;;
        powerpcle-*)    $mbig && target=${target/#powerpcle-/powerpc-} ;;
        powerpc64-*)    $mlittle && target=${target/#powerpc64-/powerpc64le-} ;;
        powerpc64le-*)  $mbig && target=${target/#powerpc64le-/powerpc64-} ;;
    esac

    # return the target
    echo "${target}"
}
