#!/bin/bash

set -e

# Accept overrides from command line if needed
sed=${SED:-sed}
grep=${GREP:-grep}

# Generate either a choice or a menuconfig with the specified entries.
#
# Usage:
#   generate a choice:
#       gen_choice <out-file> <label> <config-prefix> <base-dir>
#
#   generate a menuconfig:
#       gen_menu <out-file> <label> <config-prefix> <base-dir>
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

# Helper: find the base names of all *.in files in a given directory
get_components() {
    local dir="${1}"
    local f b

    for f in ${dir}/*.in; do
        b=${f#${dir}/}
        echo ${b%.in}
    done
}

# Generate a choice
# See above for usage
gen_choice() {
    local out_file="${1}"
    local label="${2}"
    local cfg_prefix="${3}"
    local base_dir="${4}"
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
    for entry in `get_components ${base_dir}`; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf 'config %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf '    bool\n'
        printf '    prompt "%s"\n' "${entry}"
        "${sed}" -r -e '/^## depends on /!d; s/^## /    /;' ${file} 2>/dev/null
        "${sed}" -r -e '/^## select /!d; s/^## /    /;' ${file} 2>/dev/null
        if "${grep}" -E '^## help' ${file} >/dev/null 2>&1; then
            printf '    help\n'
            "${sed}" -r -e '/^## help ?/!d; s/^## help ?/      /;' ${file} 2>/dev/null
        fi
        printf '\n'
    done
    printf 'endchoice\n'

    printf '\n'
    printf 'config %s\n' "${cfg_prefix}"
    for entry in `get_components ${base_dir}`; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf '    default "%s" if %s_%s\n' "${entry}" "${cfg_prefix}" "${_entry}"
    done

    printf '\n'
    for entry in `get_components ${base_dir}`; do
        file="${base_dir}/${entry}.in"
        _entry=$(printf '%s\n' "${entry}" |"${sed}" -r -s -e 's/[-.+]/_/g;')
        printf 'if %s_%s\n' "${cfg_prefix}" "${_entry}"
        printf 'source "%s"\n' "${file}"
        printf 'endif\n'
    done

    # Generate the part-2
    exec >"${out_file}.2"
    printf '# %s second part options\n' "${label}"
    printf '# Generated file, do not edit!!!\n'
    for entry in `get_components ${base_dir}`; do
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
    local file entry _entry

    # Generate the menuconfig
    exec >"${out_file}"
    printf '# %s menu\n' "${label}"
    printf '# Generated file, do not edit!!!\n'
    printf '\n'
    for entry in `get_components ${base_dir}`; do
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

mkdir -p config/gen
gen_choice config/gen/arch.in "Target Architecture" "ARCH" "config/arch"
gen_choice config/gen/kernel.in "Target OS" "KERNEL" "config/kernel"
gen_choice config/gen/cc.in "Compiler" "CC" "config/cc"
gen_choice config/gen/binutils.in "Binutils" "BINUTILS" "config/binutils"
gen_choice config/gen/libc.in "C library" "LIBC" "config/libc"
gen_menu config/gen/debug.in "Debug facilities" "DEBUG" "config/debug"
gen_menu config/gen/companion_tools.in "Companion tools" "COMP_TOOLS" "config/companion_tools"
