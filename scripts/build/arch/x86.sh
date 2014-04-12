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
}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "multilib flags" "target tuple"
CT_DoArchMultilibTarget ()
{
    local multi_flags="${1}"
    local target="${2}"

    # Ugly spagetti, but more readable then previously.
    case "${multi_flags}" in
        *-m32*)
            case "${target}" in
                # Switch target to i486-<vendor>-<os>-gnu if multi_flag is m32 and CT_TARGET is x86_64-<vendor>-<os>-gnu
                x86_64-*) target=${target/#x86_64-/i486-} ;;
            esac
            ;;
        *-m64*)
            case "${target}" in
                # Switch target to x86_64-<vendor>-<os>-gnu if multi_flag is m64 and CT_TARGET is x86_64-<vendor>-<os>-gnux32
                x86_64-*gnux32) target=${target/%-gnux32/-gnu} ;;
                # Switch target to x86_64-<vendor>-<os>-gnu if multi_flag is m64 and CT_TARGET is i[34567]86-<vendor>-<os>-gnu
                i[34567]86-*) target=${target/#i[34567]86-/x86_64-} ;;
            esac
            ;;
        *-mx32*)
            case "${target}" in
                # Invalid CT_TARGET: i[34567]86-<vendor>-<os>-gnux32 is invalid. Error out.
                # Maybe next patch revision, I'll just check for this in crosstool-NG.sh.in or ct-ng.in.
                i[34567]86-*gnux32)
                    CT_DoLog ERROR "Invalid CT_TARGET: i[34567]86-<vendor>-<os>-gnux32 is invalid."
                    CT_DoLog ERROR "CT_TARGET: ${CT_TARGET}"
                    CT_Abort "Go read: https://wiki.debian.org/Multiarch/Tuples"
                    ;;
                # Switch target to x86_64-<vendor>-<os>-gnux32 if multi_flag is mx32 and CT_TARGET is x86_64-<vendor>-<os>-gnu
                x86_64-*gnu) target=${target/%-gnu/-gnux32} ;;
                # Switch target to x86_64-<vendor>-<os>-gnux32 if multi_flag is mx32 and CT_TARGET is i[34567]86-<vendor>-<os>-gnu
                i[34567]86-*)
                    target=${target/%-gnu/-gnux32}
                    target=${target/#i[34567]86-/x86_64-}
                    ;;
            esac
            ;;
    esac

    case "${target}" in
    esac

    echo "${target}"
}
