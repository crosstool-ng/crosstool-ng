# Wrapper to build the companion tools facilities

# List all companion tools facilities, and parse their scripts
CT_CC_FACILITY_LIST=
for f in "${CT_LIB_DIR}/scripts/build/cc/"*.sh; do
    _f="$(basename "${f}" .sh)"
    _f="${_f#???-}"
    __f="CT_CC_${_f}"
    if [ "${!__f}" = "y" ]; then
        CT_DoLog DEBUG "Enabling cc '${_f}'"
        . "${f}"
        CT_CC_FACILITY_LIST="${CT_CC_FACILITY_LIST} ${_f}"
    else
        CT_DoLog DEBUG "Disabling cc '${_f}'"
    fi
done

# Download the cc facilities
do_cc_get() {
    for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_get
    done
}

# Extract and patch the cc facilities
do_cc_extract() {
    for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_extract
    done
}

# Core pass 1 the cc facilities
do_cc_core_pass_1() {
    for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_core_pass_1
    done
}

# Core pass 2 the cc facilities
do_cc_core_pass_2() {
	for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_core_pass_2
    done
}

# Build for build the cc facilities
do_cc_for_build() {
	for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_for_build
    done
}

# Build for host the cc facilities
do_cc_for_host() {
	for f in ${CT_CC_FACILITY_LIST}; do
        do_${f}_for_host
    done
}
