# This file provides the default implementations of arch-specific functions.

# Set up the target tuple
CT_DoArchTupleValues() {
    :;
}

# Multilib: change the target triplet according to CFLAGS
CT_DoArchMultilibTarget() {
    local multi_flags="${1}"
    local target="${2}"

    echo "${target}"
}

# Multilib: Adjust target tuple for GLIBC
CT_DoArchGlibcAdjustTuple() {
    local target="${1}"

    echo "${target}"
}

# Override from the actual arch implementation as needed.
. "${CT_LIB_DIR}/scripts/build/arch/${CT_ARCH}.sh"
