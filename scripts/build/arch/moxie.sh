# Moxie-specific arch callbacks

# No arch-specific overrides yet
CT_DoArchTupleValues()
{
    case "${CT_LIBC}" in
    moxiebox)
        CT_TARGET_SYS=moxiebox
        ;;
    esac
}
