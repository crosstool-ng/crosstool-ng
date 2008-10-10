# Wrapper to build the tools facilities

# List all tools facilities, and parse their scripts
CT_TOOLS_FACILITY_LIST=
for f in "${CT_LIB_DIR}/scripts/build/tools/"*.sh; do
    _f="$(basename "${f}" .sh)"
    _f="${_f#???-}"
    __f="CT_TOOL_${_f}"
    if [ "${!__f}" = "y" ]; then
        CT_DoLog DEBUG "Enabling tool '${_f}'"
        . "${f}"
        CT_TOOLS_FACILITY_LIST="${CT_TOOLS_FACILITY_LIST} ${_f}"
    else
        CT_DoLog DEBUG "Disabling tool '${_f}'"
    fi
done

# Download the tools facilities
do_tools_get() {
    for f in ${CT_TOOLS_FACILITY_LIST}; do
        do_tools_${f}_get
    done
}

# Extract and patch the tools facilities
do_tools_extract() {
    for f in ${CT_TOOLS_FACILITY_LIST}; do
        do_tools_${f}_extract
    done
}

# Build the tools facilities
do_tools() {
    for f in ${CT_TOOLS_FACILITY_LIST}; do
        do_tools_${f}_build
    done
}

