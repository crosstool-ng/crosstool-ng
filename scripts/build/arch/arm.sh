# Compute ARM-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${target_endian_eb}"

    # The system part of the tuple:
    case "${CT_LIBC},${CT_ARCH_ARM_EABI}" in
        *glibc,y)   CT_TARGET_SYS=gnueabi;;
        uClibc,y)   CT_TARGET_SYS=uclibcgnueabi;;
        none,y)     CT_TARGET_SYS=eabi;;
    esac

    # In case we're EABI, do *not* specify any ABI!
    # which means, either we do not have an ABI specified, or we're not EABI.
    CT_TestOrAbort "Internal error: CT_ARCH_ABI should not be set for EABI build." -z "${CT_ARCH_ABI}" -o -z "${CT_ARCH_ARM_EABI}"
}
