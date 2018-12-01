# Compute AVR-specific values

CT_DoArchTupleValues() {
    CT_TARGET_ARCH="${CT_ARCH}"
    case "${CT_LIBC}" in
    avr-libc)
        # avr-libc only seems to work with the non-canonical "avr" target.
        CT_TARGET_SKIP_CONFIG_SUB=y
        CT_TARGET_SYS= # CT_TARGET_SYS must be empty
        ;;
    esac
}
