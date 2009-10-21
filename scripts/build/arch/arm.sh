# Compute ARM-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${target_endian_eb}"

    # The system part of the tuple:
    case "${CT_LIBC},${CT_ARCH_ARM_EABI}" in
        *glibc,y)   CT_TARGET_SYS=gnueabi;;
        uClibc,y)   CT_TARGET_SYS=uclibcgnueabi;;
        *,y)        CT_TARGET_SYS=eabi;;
    esac
}
