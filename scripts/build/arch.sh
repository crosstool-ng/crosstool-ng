# This file provides the default implementations of arch-specific functions.

# Set up the target tuple
CT_DoArchTupleValues() {
    :;
}

# Multilib: change the target triplet according to CFLAGS
# Usage: CT_DoArchGlibcAdjustTuple <variable-name> <CFLAGS>
CT_DoArchMultilibTarget() {
    :;
}

# Multilib: Adjust target tuple for GLIBC
# Usage: CT_DoArchGlibcAdjustTuple <variable-name>
CT_DoArchGlibcAdjustTuple() {
    :;
}

# Helper for uClibc configurators: select the architecture
# Usage: CT_DoArchUClibcSelectArch <config-file> <architecture>
CT_DoArchUClibcSelectArch() {
    local cfg="${1}"
    local arch="${2}"

    ${sed} -i -r -e '/^TARGET_.*/d' "${cfg}"
    CT_KconfigEnableOption "TARGET_${arch}" "${cfg}"
    CT_KconfigSetOption "TARGET_ARCH" "${arch}" "${cfg}"
}

# uClibc: Adjust configuration file according to the CT-NG configuration
# Usage CT_DoArchUClibcConfig <config-file>
CT_DoArchUClibcConfig() {
    CT_DoLog WARN "Support for '${CT_ARCH}' is not implemented in uClibc config tweaker."
    CT_DoLog WARN "Exact configuration file must be provided."
}

# Override from the actual arch implementation as needed.
. "${CT_LIB_DIR}/scripts/build/arch/${CT_ARCH}.sh"
