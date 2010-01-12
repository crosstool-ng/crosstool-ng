# Wrapper to build the companion tools facilities

# List all companion tools facilities, and parse their scripts
CT_COMP_TOOLS_FACILITY_LIST=
for f in "${CT_LIB_DIR}/scripts/build/companion_tools/"*.sh; do
    _f="$(basename "${f}" .sh)"
    _f="${_f#???-}"
    __f="CT_COMP_TOOLS_${_f}"
    if [ "${!__f}" = "y" ]; then
        CT_DoLog DEBUG "Enabling companion tools '${_f}'"
        . "${f}"
        CT_COMP_TOOLS_FACILITY_LIST="${CT_COMP_TOOLS_FACILITY_LIST} ${_f}"
    else
        CT_DoLog DEBUG "Disabling companion tools '${_f}'"
    fi
done

# Download the companion tools facilities
do_companion_tools_get() {
    for f in ${CT_COMP_TOOLS_FACILITY_LIST}; do
        do_companion_tools_${f}_get
    done
}

# Extract and patch the companion tools facilities
do_companion_tools_extract() {
    for f in ${CT_COMP_TOOLS_FACILITY_LIST}; do
        do_companion_tools_${f}_extract
    done
}

# Build the companion tools facilities
do_companion_tools() {
    for f in ${CT_COMP_TOOLS_FACILITY_LIST}; do
        do_companion_tools_${f}_build
    done
}

