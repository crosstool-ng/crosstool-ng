# Compute or1k-specific values

CT_DoArchTupleValues() {
    CT_TARGET_ARCH="or1k"
}

CT_DoArchUClibcConfig()
{
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "or1k"
}
