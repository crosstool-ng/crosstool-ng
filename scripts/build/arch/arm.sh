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

CT_DoArchUClibcConfig() {
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "arm"

    # FIXME: CONFIG_ARM_OABI does not exist in neither uClibc/uClibc-ng
    # FIXME: CONFIG_ARM_EABI does not seem to affect anything in either of them, too
    # (both check the compiler's built-in define, __ARM_EABI__ instead) except for
    # a check for match between toolchain configuration and uClibc-ng in
    # uClibc_arch_features.h
    if [ "${CT_ARCH_ARM_EABI}" = "y" ]; then
        CT_KconfigDisableOption "CONFIG_ARM_OABI" "${cfg}"
        CT_KconfigEnableOption "CONFIG_ARM_EABI" "${cfg}"
    else
        CT_KconfigDisableOption "CONFIG_ARM_EABI" "${cfg}"
        CT_KconfigEnableOption "CONFIG_ARM_OABI" "${cfg}"
    fi
}
