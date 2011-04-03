# Compute sparc-specific values
CT_DoArchTupleValues() {
    # That's the only thing to override
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="${CT_ARCH}64"
    fi

}
