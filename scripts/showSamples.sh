#!/bin/bash

# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

opt="$1"
[ "${opt}" = "-v" ] && shift || opt=

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

# Dump a single sample
dump_single_sample() {
    local verbose=0
    [ "$1" = "-v" ] && verbose=1 && shift
    local width="$1"
    local sample="$2"
    if [ -f "${CT_TOP_DIR}/samples/${sample}/crosstool.config" ]; then
        sample_top="${CT_TOP_DIR}"
        sample_type="local"
    else
        sample_top="${CT_LIB_DIR}"
        sample_type="global"
    fi
    printf "  %-*s  (%s" ${width} "${sample}" "${sample_type}"
    [ -f "${sample_top}/samples/${sample}/broken" ] && printf ",broken"
    echo ")"
    if [ ${verbose} -ne 0 ]; then
        . "${sample_top}/samples/${sample}/crosstool.config"
        echo    "    OS        : ${CT_KERNEL}-${CT_KERNEL_VERSION}"
        echo    "    binutils  : binutils-${CT_BINUTILS_VERSION}"
        echo -n "    C compiler: ${CT_CC}-${CT_CC_VERSION} (C"
        [ "${CT_CC_LANG_CXX}" = "y"     ] && echo -n ",C++"
        [ "${CT_CC_LANG_FORTRAN}" = "y" ] && echo -n ",Fortran"
        [ "${CT_CC_LANG_JAVA}" = "y"    ] && echo -n ",Java"
        [ "${CT_CC_LANG_ADA}" = "y"     ] && echo -n ",ADA"
        [ "${CT_CC_LANG_OBJC}" = "y"    ] && echo -n ",Objective-C"
        [ "${CT_CC_LANG_OBJCXX}" = "y"  ] && echo -n ",Objective-C++"
        [ -n "${CT_CC_LANG_OTHERS}"     ] && echo -n ",$CT_CC_LANG_OTHERS}"
        echo    ")"
        echo    "    C library : ${CT_LIBC}-${CT_LIBC_VERSION}"
        echo -n "    Tools     :"
        [ "${CT_LIBELF}"  ] && echo -n " libelf-${CT_LIBELF_VERSION}"
        [ "${CT_SSTRIP}"  ] && echo -n " sstrip"
        [ "${CT_DMALLOC}" ] && echo -n " dmalloc-${CT_DMALLOC_VERSION}"
        [ "${CT_DUMA}"    ] && echo -n " duma-${CT_DUMA_VERSION}"
        [ "${CT_GDB}"     ] && echo -n " gdb-${CT_GDB_VERSION}"
        [ "${CT_LTRACE}"  ] && echo -n " ltrace-${CT_LTRACE_VERSION}"
        [ "${CT_STRACE}"  ] && echo -n " strace-${CT_STRACE_VERSION}"
        echo
        echo
    fi
}

# Get largest sample width
width=0
for sample in "${@}"; do
    [ ${#sample} -gt ${width} ] && width=${#sample}
done

for sample in "${@}"; do
    ( dump_single_sample ${opt} ${width} "${sample}" )
done
