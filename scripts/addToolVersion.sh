#!/bin/sh
set -e

# Adds a new version to one of the toolchain component
myname="$0"

# Parse the tools' paths configuration
# It is expected that this script is only to be run from the
# source directory of crosstool-NG, so it is trivial to find
# paths.sh (we can't use  ". paths.sh", as POSIX states that
# $PATH should be searched for, and $PATH most probably doe
# not include "."), hence the "./".
. "./paths.sh"

doHelp() {
    cat <<-EOF
		Usage: ${myname} <--tool> <[options] version [...]> ...
		  'tool' in one of:
		    gcc, binutils, glibc, uClibc, newlib, linux, gdb, dmalloc,
		    duma, strace, ltrace, libelf, gmp, mpfr, ppl, cloog, mpc,
		    mingw-w64, expat, ncurses
		
		  Valid options for all tools:
		    --stable, -s, +x   (default)
		      mark the version as being stable (as opposed to experimental, below)
		
		    --experimental, -x, +s
		      mark the version as being experimental (as opposed to stable, above)
		
		    --current, -c, +o   (default)
		      mark the version as being cuurent (as opposed to obsolete, below)
		
		    --obsolete, -o, +c
		      mark the version as being obsolete (as opposed to current, above)
		
		  Note: setting a new tool resets to the defaults: 'stable' and 'current'.
		
		  'version' is a valid version for the specified tool.
		
		  Examples:
		    add stable current version 2.6.19.2 to linux kernel:
		      ${myname} --linux 2.6.19.2
		
		    add experimental obsolete version 2.3.5 and stable current versions 2.6.1
		    and 2.6.2 to glibc, add stable obsolete version 3.3.3 to gcc:
		      ${myname} --glibc -x -o 2.3.5 -s -c 2.6.1 2.6.2 --gcc -o 3.3.3
		EOF
}

# Extract field $3 from version $1 with separator $2
getVersionField() {
    local version="$1"
    local sep="$2"
    local field="$3"

    echo "${version}${sep}${sep}${sep}${sep}" |cut -d ${sep} -f ${field}
}

# Effectively add a version to the specified tool
# $cat          : tool category
# $tool         : tool name
# $tool_prefix  : tool directory prefix
# $EXP          : set to non empty if experimental, to empty otherwise
# #OBS          : set to non empty if obsolete, to empty otherwise
# $1            : version string to add
addToolVersion() {
    local version="$1"
    local file="$2"
    local config_ver_option
    local exp_obs_prompt
    local deps v ver_M ver_m ver_p
    local SedExpr1 SedExpr2

    [ -f "${file}" ] || return 0

    v=$(echo "${version}" |"${sed}" -r -e 's/-/_/g; s/\./_/g;')

    config_ver_option="${cat}_V_${v}"

    # Check for existing version: it can be legitimitate for an end-user
    # to try adding a new version if the one he/she wants is not listed.
    # But it can be the case where the version is hidden behind either one
    # of EXPERIMENTAL or OBSOLETE, so warn if the version is already listed.
    if ${grep} -E "^config ${config_ver_option}$" "${file}" >/dev/null 2>&1; then
        echo "'${tool}': version '${version}' already present:"
        ${grep} -A1 -B0 -n                                                     \
             -E "^(config ${config_ver_option}| {4}prompt \"${version}\")$" \
             "${file}" /dev/null
        return 0
    fi

    SedExpr1="${SedExpr1}config ${config_ver_option}\n"
    SedExpr1="${SedExpr1}    bool\n"
    SedExpr1="${SedExpr1}    prompt \"${version}"
    case "${EXP},${OBS}" in
        ,)  ;;
        ,*) exp_obs_prompt=" (OBSOLETE)"
            deps="    depends on OBSOLETE"
            ;;
        *,) exp_obs_prompt=" (EXPERIMENTAL)"
            deps="    depends on EXPERIMENTAL"
            ;;
        *)  exp_obs_prompt=" (EXPERIMENTAL, OBSOLETE)"
            deps="    depends on EXPERIMENTAL \\&\\& OBSOLETE"
            ;;
    esac
    [ -n "${exp_obs_prompt}" ] && SedExpr1="${SedExpr1}${exp_obs_prompt}"
    SedExpr1="${SedExpr1}\""
    [ -n "${deps}" ] && SedExpr1="${SedExpr1}\n${deps}"
    case "${tool}" in
        gcc)
            # Extract 'M'ajor and 'm'inor from version string
            ver_M=$(getVersionField "${version}" . 1)
            ver_m=$(getVersionField "${version}" . 2)
            if [ ${ver_M} -ge 4 ] && [ ${ver_m} -ge 2 ]; then
                SedExpr1="${SedExpr1}\n    select CC_GCC_${ver_M}_${ver_m}"
            fi
            ;;
        binutils)
            # Extract 'M'ajor and 'm'inor from version string
            ver_M=$(getVersionField "${version}" . 1)
            ver_m=$(getVersionField "${version}" . 2)
            if [   \( ${ver_M} -eq 2 -a ${ver_m} -eq 22 \)  ]; then
                SedExpr1="${SedExpr1}\n    select BINUTILS_2_22_or_later"
            elif [ \( ${ver_M} -eq 2 -a ${ver_m} -eq 21 \)  ]; then
                SedExpr1="${SedExpr1}\n    select BINUTILS_2_21_or_later"
            elif [ \( ${ver_M} -eq 2 -a ${ver_m} -eq 20 \)  ]; then
                SedExpr1="${SedExpr1}\n    select BINUTILS_2_20_or_later"
            elif [ \( ${ver_M} -eq 2 -a ${ver_m} -eq 19 \)  ]; then
                SedExpr1="${SedExpr1}\n    select BINUTILS_2_19_or_later"
            elif [ \( ${ver_M} -eq 2 -a ${ver_m} -eq 18 \)  ]; then
                SedExpr1="${SedExpr1}\n    select BINUTILS_2_18_or_later"
            fi
            ;;
        uClibc)
            # uClibc-0.9.33.2 needs some love
            ver_M=$(getVersionField "${version}" . 1)
            ver_m=$(getVersionField "${version}" . 2)
            ver_p=$(getVersionField "${version}" . 3)
            elif [  ${ver_M} -eq 0 -a ${ver_m} -eq 9 -a ${ver_p} -eq 33 ]; then
                SedExpr1="${SedExpr1}\n    select LIBC_UCLIBC_0_9_33_2_or_later"
            fi
            ;;
        gdb)
            # gdb-7.0 and above have special handling
            ver_M=$(getVersionField "${version}" . 1)
            if [ ${ver_M} -ge 7 ]; then
                if [ ${ver_m} -ge 2 ]; then
                    SedExpr1="${SedExpr1}\n    select GDB_7_2_or_later"
                else
                    SedExpr1="${SedExpr1}\n    select GDB_7_0_or_later"
                fi
            fi
            ;;
    esac
    SedExpr2="    default \"${version}\" if ${config_ver_option}"
    "${sed}" -r -i -e 's/^(# CT_INSERT_VERSION_BELOW)$/\1\n\n'"${SedExpr1}"'/;' "${file}"
    "${sed}" -r -i -e 's/^(# CT_INSERT_VERSION_STRING_BELOW)$/\1\n'"${SedExpr2}"'/;' "${file}"
}

cat=
tool=
tool_prefix=
VERSION=
EXP=
OBS=

if [ $# -eq 0 ]; then
    doHelp
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        # Tools:
        --gcc)      EXP=; OBS=; cat=CC_GCC;         tool=gcc;       tool_prefix=cc;             dot2suffix=;;
        --binutils) EXP=; OBS=; cat=BINUTILS;       tool=binutils;  tool_prefix=binutils;       dot2suffix=;;
        --glibc)    EXP=; OBS=; cat=LIBC_GLIBC;     tool=glibc;     tool_prefix=libc;           dot2suffix=;;
        --uClibc)   EXP=; OBS=; cat=LIBC_UCLIBC;    tool=uClibc;    tool_prefix=libc;           dot2suffix=;;
        --newlib)   EXP=; OBS=; cat=LIBC_NEWLIB;    tool=newlib;    tool_prefix=libc;           dot2suffix=;;
        --mingw-w64)EXP=; OBS=; cat=WINAPI;         tool=mingw;     tool_prefix=libc;           dot2suffix=;;
        --linux)    EXP=; OBS=; cat=KERNEL;         tool=linux;     tool_prefix=kernel;         dot2suffix=;;
        --gdb)      EXP=; OBS=; cat=GDB;            tool=gdb;       tool_prefix=debug;          dot2suffix=;;
        --dmalloc)  EXP=; OBS=; cat=DMALLOC;        tool=dmalloc;   tool_prefix=debug;          dot2suffix=;;
        --duma)     EXP=; OBS=; cat=DUMA;           tool=duma;      tool_prefix=debug;          dot2suffix=;;
        --strace)   EXP=; OBS=; cat=STRACE;         tool=strace;    tool_prefix=debug;          dot2suffix=;;
        --ltrace)   EXP=; OBS=; cat=LTRACE;         tool=ltrace;    tool_prefix=debug;          dot2suffix=;;
        --gmp)      EXP=; OBS=; cat=GMP;            tool=gmp;       tool_prefix=companion_libs; dot2suffix=;;
        --mpfr)     EXP=; OBS=; cat=MPFR;           tool=mpfr;      tool_prefix=companion_libs; dot2suffix=;;
        --ppl)      EXP=; OBS=; cat=PPL;            tool=ppl;       tool_prefix=companion_libs; dot2suffix=;;
        --cloog)    EXP=; OBS=; cat=CLOOG;          tool=cloog;     tool_prefix=companion_libs; dot2suffix=;;
        --mpc)      EXP=; OBS=; cat=MPC;            tool=mpc;       tool_prefix=companion_libs; dot2suffix=;;
        --libelf)   EXP=; OBS=; cat=LIBELF;         tool=libelf;    tool_prefix=companion_libs; dot2suffix=;;
        --expat)    EXP=; OBS=; cat=EXPAT;          tool=expat;     tool_prefix=companion_libs; dot2suffix=;;
        --ncurses)  EXP=; OBS=; cat=NCURSES;        tool=ncurses;   tool_prefix=companion_libs; dot2suffix=;;

        # Tools options:
        -x|--experimental|+s)   EXP=1;;
        -s|--stable|+x)         EXP=;;
        -o|--obsolete|+c)       OBS=1;;
        -c|--current|+o)        OBS=;;

        # Misc:
        -h|--help)  doHelp; exit 0;;
        -*)         echo "Unknown option: '$1' (use -h/--help for help)."; exit 1;;

        # Version string:
        *)  [ -n "${tool}" ] || { doHelp; exit 1; }
            file_base="config/${tool_prefix}/${tool}.in"
            addToolVersion "$1" "${file_base}${dot2suffix}"
            ;;
    esac
    shift
done
