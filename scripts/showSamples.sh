#!/bin/bash

# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

# Dump a single sample
dump_single_sample() {
    local width="$1"
    local sample="$2"
    . "${CT_TOP_DIR}/samples/${sample}/crosstool.config"
    # Build the components string
    local str="${CT_KERNEL}-${CT_KERNEL_VERSION}"
    str="${str} binutils-${CT_BINUTILS_VERSION}"
    str="${str} ${CT_CC}-${CT_CC_VERSION}"
    str="${str} ${CT_LIBC}-${CT_LIBC_VERSION}"
    printf "  %-*s - %s\n" ${width} "${sample}" "${str}"
}

# Get largest sample width
width=0
for sample in "${@}"; do
    [ ${#sample} -gt ${width} ] && width=${#sample}
done

for sample in "${@}"; do
    ( dump_single_sample ${width} "${sample}" )
done
