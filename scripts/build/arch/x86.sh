# Compute x86-specific values

# This one really needs a little love! :-(

CT_DoArchTupleValues() {
    # Override the architecture part of the tuple:
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH=x86_64
    else
        arch="${CT_ARCH_ARCH}"
        [ -z "${arch}" ] && arch="${CT_ARCH_TUNE}"
        case "${arch}" in
            "")                           CT_TARGET_ARCH=i386;;
            i386|i486|i586|i686)          CT_TARGET_ARCH="${arch}";;
            winchip*)                     CT_TARGET_ARCH=i486;;
            pentium|pentium-mmx|c3*)      CT_TARGET_ARCH=i586;;
            pentiumpro|pentium*|athlon*)  CT_TARGET_ARCH=i686;;
            prescott)                     CT_TARGET_ARCH=i686;;
            *)                            CT_TARGET_ARCH=i586;;
        esac
    fi
    CT_TARGET_ARCH="${CT_TARGET_ARCH}${CT_ARCH_SUFFIX}"

    # Shouldn't be possible to specify this (CT_TARGET_SYS is not specified by the user,
    # it is computed by scripts/functions from libc choices). But trap if such invalid
    # values ever come from the caller:
    case "${CT_TARGET_ARCH}-${CT_TARGET_SYS}" in
        i[34567]86-gnux32)
            CT_DoLog ERROR "Invalid CT_TARGET: i[34567]86-<vendor>-<os>-gnux32 is invalid."
            CT_DoLog ERROR "CT_TARGET: ${CT_TARGET}"
            CT_Abort "Go read: https://wiki.debian.org/Multiarch/Tuples"
            ;;
    esac
}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "multilib flags" "target tuple"
CT_DoArchMultilibTarget ()
{
    local target="${1}"; shift
    local -a multi_flags=( "$@" )

    local bit32=false
    local bit64=false
    local abi_dflt=false
    local abi_x32=false

    for m in "${multi_flags[@]}"; do
        case "$m" in
            -m32)  bit32=true; abi_dflt=true;;
            -m64)  bit64=true; abi_dflt=true;;
            -mx32) bit64=true; abi_x32=true;;
        esac
    done

    # Fix up architecture.
    case "${target}" in
        x86_64-*)      $bit32 && target=${target/#x86_64-/i386-} ;;
        i[34567]86-*)  $bit64 && target=${target/#i[34567]86-/x86_64-} ;;
    esac

    # Fix up the ABI part.
    case "${target}" in
        *x32) $abi_dflt && target=${target/%x32} ;;
        *)    $abi_x32  && target=${target}x32 ;;
    esac

    echo "${target}"
}
