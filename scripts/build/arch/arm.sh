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

    # Set the default instrcution set mode
    case "${CT_ARCH_ARM_MODE}" in
        arm)    ;;
        thumb)
            CT_ARCH_CC_CORE_EXTRA_CONFIG="--with-mode=thumb"
            CT_ARCH_CC_EXTRA_CONFIG="--with-mode=thumb"
#            CT_ARCH_TARGET_CFLAGS="-mthumb"
            ;;
    esac

    if [ "${CT_ARCH_ARM_INTERWORKING}" = "y" ]; then
        CT_ARCH_TARGET_CFLAGS+=" -mthumb-interwork"
    fi
}
