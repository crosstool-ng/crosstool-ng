# Wrapper to build the debug facilities

# List all debug facilities, and parse their scripts
CT_DEBUG_FACILITY_LIST=
for f in "${CT_LIB_DIR}/scripts/build/debug/"*.sh; do
    is_enabled=
    . "${f}"
    f=`basename "${f}" .sh`
    if [ "${is_enabled}" = "y" ]; then
        CT_DEBUG_FACILITY_LIST="${CT_DEBUG_FACILITY_LIST} ${f}"
    fi
done

# Download the debug facilities
do_debug_get() {
    for f in ${CT_DEBUG_FACILITY_LIST}; do
        do_debug_${f}_get
    done
}

# Extract and patch the debug facilities
do_debug_extract() {
    for f in ${CT_DEBUG_FACILITY_LIST}; do
        do_debug_${f}_extract
    done
}

# Build the debug facilities
do_debug() {
    for f in ${CT_DEBUG_FACILITY_LIST}; do
        do_debug_${f}_build
    done
}

