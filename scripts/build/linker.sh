# Wrapper to build the standalone linkers

# List all linkers, and parse their scripts
CT_LINKER_LIST=
for f in "${CT_LIB_DIR}/scripts/build/linker/"*.sh; do
    _f="$(basename "${f}" .sh)"
    _f="${_f#???-}"
    __f="CT_LINKER_${_f^^}"
    if [ "${!__f}" = "y" ]; then
        CT_DoLog DEBUG "Enabling linker '${_f}'"
        . "${f}"
        CT_LINKER_LIST="${CT_LINKER_LIST} ${_f}"
    else
        CT_DoLog DEBUG "Disabling linker '${_f}'"
    fi
done

# Download the linkers
do_linker_get() {
    for f in ${CT_LINKER_LIST}; do
        do_linker_${f}_get
    done
}

# Extract and patch the linkers
do_linker_extract() {
    for f in ${CT_LINKER_LIST}; do
        do_linker_${f}_extract
    done
}

# Build the linkers
do_linker() {
    for f in ${CT_LINKER_LIST}; do
        do_linker_${f}_build
    done
}

