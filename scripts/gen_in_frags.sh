#!/bin/sh
set -e

# This scripts generates either a choice or a menuconfig
# with the specified entries.
#
# Usage:
#   generate a choice:
#       gen_in_frags.sh choice <out-file> <label> <config-prefix> <base-dir> <conditionals> entry [entry...]
#
#   generate a menuconfig:
#       gen_in_frags.sh menu <out-file> <label> <config-prefix> <base-dir> entry [entry...]
#
# where:
#   out-file
#       put the generated choice/menuconfig into that file
#       for choices, it acts as the base bname of the file, the secondary
#       parts (the .in.2) are put in out-file.2
#
#   label
#       name for the entries family
#       eg. Architecture, Kernel...
#
#   config-prefix
#       prefix for the choice entries
#       eg. ARCH, KERNEL...
#
#   base-dir
#       base directory containing config files
#       eg. config/arch, config/kernel...
#
#   conditionals (valid only for choice)
#       generate backend conditionals if Y/y, don't if anything else
#       if 'Y' (or 'y'), a dependency on the backen mode will be added
#       to each entry
#
#   entry [entry...]
#       a list of entry/ies toadd to the choice/menuconfig
#       eg.:
#           arm mips sh x86...
#           linux cygwin mingw32 solaris...
#           ...
#
#------------------------------------------------------------------------------

# Generate a choice
# See above for usage
gen_choice() {
    local out_file="${1}"
    local label="${2}"
    local cfg_prefix="${3}"
    local base_dir="${4}"
    local cond="${5}"
    shift 5
    local file entry _entry

    # Generate the part-1
    exec >"${out_file}"
    printf '# %s menu\n' "${label}"
    printf '# Generated file, do not edit!!!\n'
    printf '\n'
    printf 'choice GEN_CHOICE_%s\n' "${cfg_prefix}"
    printf '    bool\n'
    printf '    prompt "%s"\n' "${label}"
    printf '\n'
    for entry in "${@}"; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf 'config %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf '    bool\n'
        printf '    prompt "%s"\n' "${entry}"
        if [ "${cond}" = "Y" -o "${cond}" = "y" ]; then
            printf '    depends on %s_%s_AVAILABLE\n' "${cfg_prefix}" "${_entry}"
        fi
        "${sed}" -r -e '/^## depends on /!d; s/^## /    /;' ${file} 2>/dev/null
        "${sed}" -r -e '/^## select /!d; s/^## /    /;' ${file} 2>/dev/null
        if "${grep}" -E '^## help' ${file} >/dev/null 2>&1; then
            printf '    help\n'
            "${sed}" -r -e '/^## help ?/!d; s/^## help ?/      /;' ${file} 2>/dev/null
        fi
        printf '\n'
    done
    printf 'endchoice\n'

    for entry in "${@}"; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf '\n'
        if [ "${cond}" = "Y" -o "${cond}" = "y" ]; then
            printf 'config %s_%s_AVAILABLE\n' "${cfg_prefix}" "${_entry}"
            printf '    bool\n'
            printf '    default y if'
            printf ' BACKEND_%s = "%s"' "${cfg_prefix}" "${entry}"
            printf ' || BACKEND_%s = ""' "${cfg_prefix}"
            printf ' || ! BACKEND\n'
        fi
        printf 'if %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf 'config %s\n' "${cfg_prefix}"
        printf '    default "%s" if %s_%s\n' "${entry}" "${cfg_prefix}" "${_entry}"
        printf 'source "%s"\n' "${file}"
        printf 'endif\n'
    done

    # Generate the part-2
    exec >"${out_file}.2"
    printf '# %s second part options\n' "${label}"
    printf '# Generated file, do not edit!!!\n'
    for entry in "${@}"; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        if [ -f "${file}.2" ]; then
            printf '\n'
            printf 'if %s_%s\n' "${cfg_prefix}" "${_entry}"
            printf 'comment "%s other options"\n' "${entry}"
            printf 'source "%s.2"\n' "${file}"
            printf 'endif\n'
        fi
    done
}

# Generate a menuconfig
# See above for usage
gen_menu() {
    local out_file="${1}"
    local label="${2}"
    local cfg_prefix="${3}"
    local base_dir="${4}"
    shift 4
    local file entry _entry

    # GEnerate the menuconfig
    exec >"${out_file}"
    printf '# %s menu\n' "${label}"
    printf '# Generated file, do not edit!!!\n'
    printf '\n'
    for entry in "${@}"; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf 'menuconfig %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf '    bool\n'
        if "${grep}" -E '^## default' ${file} >/dev/null 2>&1; then
            "${sed}" -r -e '/^## default ?/!d; s/^## default ?/    default /;' ${file} 2>/dev/null
        fi
        printf '    prompt "%s"\n' "${entry}"
        "${sed}" -r -e '/^## depends on /!d; s/^## /    /;' ${file} 2>/dev/null
        "${sed}" -r -e '/^## select /!d; s/^## /    /;' ${file} 2>/dev/null
        if "${grep}" -E '^## help' ${file} >/dev/null 2>&1; then
            printf '    help\n'
            "${sed}" -r -e '/^## help ?/!d; s/^## help ?/      /;' ${file} 2>/dev/null
        fi
        printf '\n'
        printf 'if %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf 'source "%s"\n' "${file}"
        printf 'endif\n'
        printf '\n'
    done
}

type="${1}"
shift
"gen_${type}" "${@}"
