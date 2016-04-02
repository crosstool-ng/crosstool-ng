# Compute ARM-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    case "${CT_ARCH_BITNESS}" in
        32)
            CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${target_endian_eb}}"
            ;;
        64)
            # ARM 64 (aka AArch64) is special
            [ "${CT_ARCH_BE}" = "y" ] && target_endian_eb="_be"
            CT_TARGET_ARCH="aarch64${CT_ARCH_SUFFIX:-${target_endian_eb}}"
            ;;
    esac

    # The system part of the tuple:
    case "${CT_LIBC},${CT_ARCH_ARM_EABI}" in
        *glibc,y)   CT_TARGET_SYS=gnueabi;;
        uClibc,y)   CT_TARGET_SYS=uclibcgnueabi;;
        musl,y)     CT_TARGET_SYS=musleabi;;
        *,y)        CT_TARGET_SYS=eabi;;
    esac

    # Set the default instruction set mode
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

    if [ "${CT_ARCH_ARM_TUPLE_USE_EABIHF}" = "y" ]; then
        CT_TARGET_SYS="${CT_TARGET_SYS}hf"
    fi
}
