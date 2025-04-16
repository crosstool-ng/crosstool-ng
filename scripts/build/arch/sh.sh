# Compute sh-specific values

CT_DoArchTupleValues () {
    # The architecture part of the tuple. Binutils do not accept specifications
    # like 'sheb-unknown-elf' even though GCC does. So keep the tuple just sh-*-elf
    # unless user wants something specific (either CPU or explicit suffix).
    if [ "${CT_ARCH_SH_VARIANT}" != "sh" -o -n "${CT_ARCH_SUFFIX}" ]; then
        CT_TARGET_ARCH="${CT_ARCH_SH_VARIANT}${CT_ARCH_SUFFIX:-${CT_ARCH_SH_FLOAT_SUFFIX}${target_endian_eb}}"
    fi

    # Endianness stuff (uses non-standard CFLAGS). If both are compiled, let the
    # compiler's default or multilib iterator be used.
    case "${CT_ARCH_ENDIAN}" in
        big)    CT_ARCH_ENDIAN_CFLAG=-mb;;
        little) CT_ARCH_ENDIAN_CFLAG=-ml;;
    esac

    # Instead of -m{soft,hard}-float, uses CPU type
    CT_ARCH_FLOAT_CFLAG=
    if [ "${CT_ARCH_SH_VARIANT}" != "sh" ]; then
        CT_ARCH_ARCH_CFLAG=-m${CT_ARCH_SH_VARIANT#sh}-${CT_ARCH_SH_FLOAT_SUFFIX#_}
    fi
}

CT_DoArchMultilibList() {
    local save_ifs="${IFS}"
    local new
    local x

    # In a configuration for SuperH, GCC list of multilibs shall not include
    # the default CPU. E.g. if configuring for sh4-*-*, we need to remove
    # "sh4" or "m4" from the multilib list. Otherwise, the resulting compiler
    # will fail when that CPU is selected explicitly "sh4-multilib-linux-gnu-gcc -m4 ..."
    # as it will fail to find the sysroot with that suffix. This applies to both
    # the CPU type inferred from the target tuple (CT_ARCH_SH_VARIANT) as well as
    # the default CPU configured with --with-cpu (CT_ARCH_CPU).
    IFS=,
    for x in ${CT_CC_GCC_MULTILIB_LIST}; do
        if [ "${x}" = "${CT_ARCH_ARCH_CFLAG#-}" -o "sh${x#m}" = "${CT_ARCH_ARCH_CFLAG#-}" ]; then
            CT_DoLog WARN "Ignoring '${x}' in multilib list: it is the default multilib"
            continue
        fi
        if [ "${x}" = "${CT_ARCH_CPU}" -o "sh${x#m}" = "${CT_ARCH_CPU}" -o "m${x#sh}" = "${CT_ARCH_CPU}" ]; then
            CT_DoLog WARN "Ignoring '${x}' in multilib list: it is the default multilib"
            continue
        fi
        new="${new:+${new},}${x}"
    done
    IFS="${save_ifs}"
    CT_CC_GCC_MULTILIB_LIST="${new}"
    CT_DoLog DEBUG "Adjusted CT_CC_GCC_MULTILIB_LIST to '${CT_CC_GCC_MULTILIB_LIST}'"
}

#------------------------------------------------------------------------------
# Get multilib architecture-specific target
# Usage: CT_DoArchMultilibTarget "target variable" "multilib flags"
CT_DoArchMultilibTarget ()
{
    local target_var="${1}"; shift
    local -a multi_flags=( "$@" )
    local target_
    local newcpu

    for m in "${multi_flags[@]}"; do
        case "${m}" in
            -m[12345]*) newcpu=sh${m#-m}; newcpu=${newcpu/_/-}; newcpu=${newcpu/_/-};;
        esac
    done

    eval target_=\"\${${target_var}}\"

    # Strip CPU name and append the new one if an option has been seen.
    if [ -n "${newcpu}" ]; then
        target_="${newcpu}-${target_#*-}"
    fi

    # Set the target variable
    eval ${target_var}=\"${target_}\"
}

# Adjust target tuple for GLIBC
CT_DoArchGlibcAdjustTuple() {
    local target_var="${1}"
    local target_
    local newtarget

    eval target_=\"\${${target_var}}\"

    case "${target_}" in
        sh-*)
            # Glibc does not build unless configured with 'shX-*' tuple.
            # Since we ended up here, no architecture variant has been
            # specified, so the only source of default is CT_ARCH_CPU.
            # GCC defaults to sh1, but this Glibc cannot compile for it.
            if [ -n "${CT_ARCH_CPU}" ]; then
                newtarget=${CT_ARCH_CPU/#m/sh}
                newtarget=${newtarget/-/_}
                newtarget=${newtarget/-/_}
                target_="${newtarget}-${target_#*-}"
                CT_DoLog DEBUG "Adjusted target tuple ${target_}"
            else
                CT_Abort "GNU C library cannot build for sh1 (GCC default). " \
                        "Specify architecture variant or the default CPU type."
            fi
            ;;
    esac

    # Set the target variable
    eval ${target_var}=\"${target_}\"
}

# Multilib: Adjust configure arguments for GLIBC
# Usage: CT_DoArchGlibcAdjustConfigure <configure-args-array-name> <cflags>
CT_DoArchGlibcAdjustConfigure() {
    local -a add_args
    local array="${1}"
    local cflags="${2}"
    local opt

    for opt in ${cflags}; do
        case "${opt}" in
        -m[1-5]*-nofpu)
            add_args+=( "--without-fp" )
            ;;
        -m[1-5]*)
            add_args+=( "--with-fp" )
            ;;
        esac
    done

    # If architecture variant was specified, we'd have CT_ARCH_ARCH_CFLAG
    # and it would've been handled above. Our last resort: CT_ARCH_CPU
    if [ "${#add_args[@]}" = 0 ]; then
        case "${CT_ARCH_CPU}" in
        sh[24]a-nofpu | m[24]a-nofpu | sh4-nofpu | m4-nofpu)
            add_args+=( "--without-fp" )
            ;;
        *)
            add_args+=( "--with-fp" )
            ;;
        esac
    fi

    eval "${array}+=( \"\${add_args[@]}\" )"
}

CT_DoArchUClibcConfig() {
    local cfg="${1}"

    CT_DoArchUClibcSelectArch "${cfg}" "sh"
    CT_KconfigDisableOption "CONFIG_SH2" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH2A" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH3" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH4" "${cfg}"
    CT_KconfigDisableOption "CONFIG_SH4A" "${cfg}"
    case "${CT_ARCH_SH_VARIANT}" in
        sh2) CT_KconfigEnableOption "CONFIG_SH2" "${cfg}";;
        sh2a) CT_KconfigEnableOption "CONFIG_SH2A" "${cfg}";;
        sh3) CT_KconfigEnableOption "CONFIG_SH3" "${cfg}";;
        sh4) CT_KconfigEnableOption "CONFIG_SH4" "${cfg}";;
        sh4a) CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}";;
    esac
}

CT_DoArchUClibcCflags() {
    local cfg="${1}"
    local cflags="${2}"
    local f

    for f in ${cflags}; do
        case "${f}" in
        -ml)
            CT_KconfigDisableOption "ARCH_BIG_ENDIAN" "${dst}"
            CT_KconfigDisableOption "ARCH_WANTS_BIG_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_LITTLE_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_WANTS_LITTLE_ENDIAN" "${dst}"
            ;;
        -mb)
            CT_KconfigEnableOption "ARCH_BIG_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_WANTS_BIG_ENDIAN" "${dst}"
            CT_KconfigDisableOption "ARCH_LITTLE_ENDIAN" "${dst}"
            CT_KconfigDisableOption "ARCH_WANTS_LITTLE_ENDIAN" "${dst}"
            ;;
        -m2|-m2a|-m2a-nofpu|-m3|-m4|-m4-nofpu|-m4a|-m4a-nofpu)
            CT_KconfigDisableOption "CONFIG_SH2" "${cfg}"
            CT_KconfigDisableOption "CONFIG_SH2A" "${cfg}"
            CT_KconfigDisableOption "CONFIG_SH3" "${cfg}"
            CT_KconfigDisableOption "CONFIG_SH4" "${cfg}"
            CT_KconfigDisableOption "CONFIG_SH4A" "${cfg}"
            CT_KconfigDisableOption "UCLIBC_HAS_FPU" "${cfg}"
            case "${f}" in
            -m2)
                CT_KconfigEnableOption "CONFIG_SH2" "${cfg}"
                ;;
            -m2a)
                CT_KconfigEnableOption "CONFIG_SH2A" "${cfg}"
                CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m2a-nofpu)
                CT_KconfigEnableOption "CONFIG_SH2A" "${cfg}"
                ;;
            -m3)
                CT_KconfigEnableOption "CONFIG_SH3" "${cfg}"
                ;;
            -m4)
                CT_KconfigEnableOption "CONFIG_SH4" "${cfg}"
                CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m4-nofpu)
                CT_KconfigEnableOption "CONFIG_SH4" "${cfg}"
                ;;
            -m4a)
                CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}"
                CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${cfg}"
                ;;
            -m4a-nofpu)
                CT_KconfigEnableOption "CONFIG_SH4A" "${cfg}"
                ;;
            esac
            ;;
        esac
    done
}
