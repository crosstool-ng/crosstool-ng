#!/bin/bash

# Adds a new version to one of the toolchain component
myname="$0"

doHelp() {
    cat <<-EOF
Usage: ${myname} <tool> [option] <version>
  'tool' in one of:
    --gcc, --binutils, --glibc, --eglibc, --uClibc, --linux,
    --gdb, --dmalloc, --duma, --strace, --ltrace, --libelf
    --gmp, --mpfr

  Valid options for all tools:
    --experimental, -x
      mark the version as being experimental

    --obsolete, -o
      mark the version as being obsolete

  'version' is a valid version for the specified tool.

  Examples:
    add version 2.6.19.2 to linux kernel:
      ${myname} --linux 2.6.19.2

    add experimental versions 2.3.5 and 2.3.6 to glibc:
      ${myname} --glibc -x 2.3.5 2.3.6
EOF
}

cat=
tool=
tool_prefix=
VERSION=
EXP=
OBS=
prompt_suffix=

i=1
while [ $i -le $# ]; do
    case "${!i}" in
        # Tools:
        --gcc)              cat=CC;        tool=gcc;      tool_prefix=cc;;
        --binutils)         cat=BINUTILS;  tool=binutils; tool_prefix=;;
        --glibc)            cat=LIBC;      tool=glibc;    tool_prefix=libc;;
        --eglibc)           cat=LIBC;      tool=eglibc;   tool_prefix=libc;;
        --uClibc)           cat=LIBC;      tool=uClibc;   tool_prefix=libc;;
        --linux)            cat=KERNEL;    tool=linux;    tool_prefix=kernel;;
        --gdb)              cat=GDB;       tool=gdb;      tool_prefix=debug;;
        --dmalloc)          cat=DMALLOC;   tool=dmalloc;  tool_prefix=debug;;
        --duma)             cat=DUMA;      tool=duma;     tool_prefix=debug;;
        --strace)           cat=STRACE;    tool=strace;   tool_prefix=debug;;
        --ltrace)           cat=LTRACE;    tool=ltrace;   tool_prefix=debug;;
        --libelf)           cat=LIBELF;    tool=libelf;   tool_prefix=tools;;
        --gmp)              cat=GMP;       tool=gmp;      tool_prefix=gmp_mpfr;;
        --mpfr)             cat=MPFR;      tool=mpfr;     tool_prefix=gmp_mpfr;;
        # Tools options:
        -x|--experimental)  EXP=1; OBS=; prompt_suffix=" (EXPERIMENTAL)";;
        -o|--obsolete)      OBS=1; EXP=; prompt_suffix=" (OBSOLETE)";;
        # Misc:
        -h|--help)          doHelp; exit 0;;
        -*)                 echo "Unknown option: '${!i}' (use -h/--help for help)."; exit 1;;
        *)                  VERSION="${VERSION} ${!i}";;
    esac
    i=$((i+1))
done

[ -n "${tool}" -o -n "${VERSION}" ] || { doHelp; exit 1; }

for ver in ${VERSION}; do
    unset DEP L1 L2 L3 L4 L5 L6 FILE v ver_M ver_m
    FILE="config/${tool_prefix}/${tool}.in"
    v=$(echo "${ver}" |sed -r -e 's/-/_/g; s/\./_/g;')
    L1="config ${cat}_V_${v}\n"
    L2="    bool\n"
    L3="    prompt \"${ver}${prompt_suffix}\"\n"
    [ -n "${EXP}" ] && DEP="${DEP} && EXPERIMENTAL"
    [ -n "${OBS}" ] && DEP="${DEP} && OBSOLETE"
    [ -n "${DEP}" ] && L4="    depends on "$(echo "${DEP}" |sed -r -e 's/^ \&\& //; s/\&/\\&/g;')"\n"
    if [ "${tool}" = "gcc" ]; then
        # Extract 'M'ajor and 'm'inor from version string
        ver_M=$(echo "${ver}...." |cut -d . -f 1)
        ver_m=$(echo "${ver}...." |cut -d . -f 2)
        if [ ${ver_M} -gt 4 -o \( ${ver_M} -eq 4 -a ${ver_m} -ge 3 \) ]; then
            L5="    select CC_GCC_4_3_or_later\n"
        fi
    fi
    L6="    default \"${ver}\" if ${cat}_V_${v}"
    sed -r -i -e 's/^(# CT_INSERT_VERSION_ABOVE)$/'"${L1}${L2}${L3}${L4}${L5}"'\n\1/;'  \
              -e 's/^(# CT_INSERT_VERSION_STRING_ABOVE)$/'"${L6}"'\n\1/;'               \
              "${FILE}"
done
