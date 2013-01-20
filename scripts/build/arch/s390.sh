# Compute s390-specific values

CT_DoArchTupleValues() {
    # That's the only thing to override
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_TARGET_ARCH="s390x${CT_ARCH_SUFFIX}"
    fi
}
