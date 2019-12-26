# Compute ARC-specific values

CT_DoArchTupleValues()
{
    if [ "${CT_ARCH_ARC_ISA_V3}" = "y" ]; then
        # ARCv3 ISA is little-endian only
        # and thus "-mlittle-endian" option in GCC is obsolete for arc64
        CT_ARCH_ENDIAN_CFLAG=""
        # The same goes to the linker - we only build for little-endian.
        CT_ARCH_ENDIAN_LDFLAG=""
        case "${CT_ARCH_BITNESS}" in
            32)
                CT_TARGET_ARCH="arc32${CT_ARCH_SUFFIX}"
                ;;
            64)
                CT_TARGET_ARCH="arc64${CT_ARCH_SUFFIX}"
                ;;
        esac
    else
        CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${target_endian_eb}}"
    fi
}

CT_DoArchUClibcConfig()
{
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "arc"

    if [ "${CT_ARCH_ARC_ISA_V3}" = "y" ]; then
        CT_KconfigDisableOption "ARCH_BIG_ENDIAN" "${cfg}"
        CT_KconfigDisableOption "ARCH_WANTS_BIG_ENDIAN" "${cfg}"
        CT_KconfigEnableOption "ARCH_LITTLE_ENDIAN" "${cfg}"
        CT_KconfigEnableOption "ARCH_WANTS_LITTLE_ENDIAN" "${cfg}"
        # ARCv3 32-bit processors may only have page size of 4Kib
        CT_KconfigEnableOption "CONFIG_ARC_PAGE_SIZE_4K" "${cfg}"
        CT_KconfigDisableOption "CONFIG_ARC_PAGE_SIZE_8K" "${cfg}"
        CT_KconfigDisableOption "CONFIG_ARC_PAGE_SIZE_16K" "${cfg}"
    fi
}

# Multilib: Adjust configure arguments for GLIBC
# Usage: CT_DoArchGlibcAdjustConfigure <configure-args-array-name> <cflags>
#
# From GCC's standpoint ARC's multilib items are defined by "mcpu" values
# which we have quite a few and for all of them might be built optimized
# cross-toolchain.
#
# From Glibc's standpoint multilib is multi-ABI and so very limited
# versions are supposed to co-exist.
#
# Here we force Glibc to install libraries in per-multilib folder to create
# a universal cross-toolchain that has libs optimized for multiple CPU types.
CT_DoArchGlibcAdjustConfigure() {
    local -a add_args
    local array="${1}"
    local cflags="${2}"
    local opt
    local mcpu

    # If building for multilib, set proper installation paths
    if [ "${CT_MULTILIB}" = "y" ]; then
        for opt in ${cflags}; do
            case "${opt}" in
            -mcpu=*)
                mcpu="${opt#*=}"
                add_args+=( "libc_cv_rtlddir=/lib/${mcpu}" )
                add_args+=( "libc_cv_slibdir=/lib/${mcpu}" )
                add_args+=( "--libdir=/usr/lib/${mcpu}" )
                ;;
            esac
        done
    fi

    eval "${array}+=( \"\${add_args[@]}\" )"
}
