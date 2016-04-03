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

# Override from the actual arch implementation as needed.
. "${CT_LIB_DIR}/scripts/build/arch/${CT_ARCH}.sh"
