# Compute ARC-specific values

CT_DoArchTupleValues()
{
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${target_endian_eb}}"
}

CT_DoArchUClibcConfig()
{
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "arc"
}

CT_DoArchUClibcCflags()
{
    local cfg="${1}"
    local cflags="${2}"
    local f

    CT_KconfigDisableOption "CONFIG_ARC_HAS_ATOMICS" "${cfg}"

    for f in ${cflags}; do
        case "${f}" in
            -matomic)
                CT_KconfigEnableOption "CONFIG_ARC_HAS_ATOMICS" "${cfg}"
                ;;
        esac
    done
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
