#!/bin/sh
set -e

# Adds a new version to one of the toolchain component
myname="$0"

# Parse the tools' paths configuration
. "paths.mk"

doHelp() {
    cat <<-EOF
Usage: ${myname} <tool> <[options] version [...]> ...
  'tool' in one of:
    --gcc, --binutils, --glibc, --eglibc, --uClibc, --linux,
    --gdb, --dmalloc, --duma, --strace, --ltrace, --libelf
    --gmp, --mpfr

  Valid options for all tools:
    --stable, -s, +x   (default)
      mark the version as being stable (as opposed to experimental)

    --experimental, -x, +s
      mark the version as being experimental (as opposed to stable)

    --current, -c, +o   (default)
      mark the version as being cuurent (as opposed to obsolete)

    --obsolete, -o, +c
      mark the version as being obsolete (as opposed to current)

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

# Effectively add a version to the specified tool
# $cat          : tool category
# $tool         : tool name
# $tool_prefix  : tool directory prefix
# $EXP          : set to non empty if experimental, to empty otherwise
# #OBS          : set to non empty if obsolete, to empty otherwise
# $1            : version string to add
addToolVersion() {
    local version="$1"
    local file
    local exp_obs_prompt
    local deps v ver_M ver_m
    local SedExpr1 SedExpr2

    file="config/${tool_prefix}/${tool}.in"
    v=$(echo "${version}" |"${sed}" -r -e 's/-/_/g; s/\./_/g;')

    SedExpr1="${SedExpr1}config ${cat}_V_${v}\n"
    SedExpr1="${SedExpr1}    bool\n"
    SedExpr1="${SedExpr1}    prompt \"${version}"
    case "${EXP},${OBS}" in
        ,)  ;;
        ,*) exp_obs_prompt="  (OBSOLETE)"
            deps="    depends on OBSOLETE\n"
            ;;
        *,) exp_obs_prompt="  (EXPERIMENTAL)"
            deps="    depends on EXPERIMENTAL\n"
            ;;
        *)  exp_obs_prompt="  (EXPERIMENTAL, OBSOLETE)"
            deps="    depends on EXPERIMENTAL && OBSOLETE\n"
            ;;
    esac
    [ -n "${exp_obs_prompt}" ] && SedExpr1="${SedExpr1}${exp_obs_prompt}"
    SedExpr1="${SedExpr1}\"\n"
    [ -n "${deps}" ] && SedExpr1="${SedExpr1}${deps}"
    if [ "${tool}" = "gcc" ]; then
        # Extract 'M'ajor and 'm'inor from version string
        ver_M=$(echo "${version}...." |cut -d . -f 1)
        ver_m=$(echo "${version}...." |cut -d . -f 2)
        if [    ${ver_M} -gt 4                          \
             -o \( ${ver_M} -eq 4 -a ${ver_m} -ge 3 \)  ]; then
            SedExpr1="    select CC_GCC_4_3_or_later\n"
        fi
    fi
    SedExpr2="    default \"${version}\" if ${cat}_V_${v}"
    "${sed}" -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${SedExpr1}"'\n\1/;' "${file}"
    "${sed}" -r -i -e 's/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${SedExpr2}"'\n\1/;' "${file}"
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
        --gcc)      EXP=; OBS=; cat=CC;        tool=gcc;      tool_prefix=cc;;
        --binutils) EXP=; OBS=; cat=BINUTILS;  tool=binutils; tool_prefix=;;
        --glibc)    EXP=; OBS=; cat=LIBC;      tool=glibc;    tool_prefix=libc;;
        --eglibc)   EXP=; OBS=; cat=LIBC;      tool=eglibc;   tool_prefix=libc;;
        --uClibc)   EXP=; OBS=; cat=LIBC;      tool=uClibc;   tool_prefix=libc;;
        --linux)    EXP=; OBS=; cat=KERNEL;    tool=linux;    tool_prefix=kernel;;
        --gdb)      EXP=; OBS=; cat=GDB;       tool=gdb;      tool_prefix=debug;;
        --dmalloc)  EXP=; OBS=; cat=DMALLOC;   tool=dmalloc;  tool_prefix=debug;;
        --duma)     EXP=; OBS=; cat=DUMA;      tool=duma;     tool_prefix=debug;;
        --strace)   EXP=; OBS=; cat=STRACE;    tool=strace;   tool_prefix=debug;;
        --ltrace)   EXP=; OBS=; cat=LTRACE;    tool=ltrace;   tool_prefix=debug;;
        --libelf)   EXP=; OBS=; cat=LIBELF;    tool=libelf;   tool_prefix=tools;;
        --gmp)      EXP=; OBS=; cat=GMP;       tool=gmp;      tool_prefix=gmp_mpfr;;
        --mpfr)     EXP=; OBS=; cat=MPFR;      tool=mpfr;     tool_prefix=gmp_mpfr;;

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
            addToolVersion "$1"
            ;;
    esac
    shift
done
