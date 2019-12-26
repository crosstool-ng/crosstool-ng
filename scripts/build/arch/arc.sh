# Compute ARC-specific values

CT_DoArchTupleValues()
{
    case "${CT_ARCH_BITNESS}" in
        32)
            CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX:-${target_endian_eb}}"
            ;;
        64)
            # arc64 is little-endian only for now
            # and thus "-mlittle-endian" option in GCC is obsolete for arc64
            CT_TARGET_ARCH="arc64${CT_ARCH_SUFFIX}"
            CT_ARCH_ENDIAN_CFLAG=""
            # The same goes to the linker - we only build for little-endian.
            CT_ARCH_ENDIAN_LDFLAG=""
            ;;
    esac
}

CT_DoArchUClibcConfig()
{
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "arc"
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
