#!/bin/bash

# Parses all samples on the command line, and for each of them, prints
# the versions of the main tools

# GREP_OPTIONS screws things up.
export GREP_OPTIONS=

# Dump a single sample
dump_single_sample() {
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
}

# Get largest sample width
width=0
for sample in "${@}"; do
    [ ${#sample} -gt ${width} ] && width=${#sample}
done

for sample in "${@}"; do
    ( dump_single_sample ${width} "${sample}" )
done
