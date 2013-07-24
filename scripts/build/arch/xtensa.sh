# Compute Xtensa-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    CT_TARGET_ARCH="${CT_ARCH}${CT_ARCH_SUFFIX}"
    # The system part of the tuple:
    case "${CT_LIBC}" in
        *glibc)   CT_TARGET_SYS=gnu;;
        uClibc)   CT_TARGET_SYS=uclibc;;
    esac
}

# This function updates the specified component (binutils, gcc, gdb, etc.)
# with the processor specific configuration.
CT_ConfigureXtensa() {
    local component="${1}"
    local version="${2}"
    local custom_overlay="xtensa_${CT_ARCH_XTENSA_CUSTOM_NAME}.tar"
    local custom_location="${CT_ARCH_XTENSA_CUSTOM_OVERLAY_LOCATION}"

    if [ -z "${CT_ARCH_XTENSA_CUSTOM_NAME}" ]; then
        custom_overlay="xtensa-overlay.tar"
    fi

    if [ -n "${CT_CUSTOM_LOCATION_ROOT_DIR}" \
         -a -z "${custom_location}" ]; then
             custom_location="${CT_CUSTOM_LOCATION_ROOT_DIR}"
    fi

    CT_TestAndAbort "${custom_overlay}: CT_CUSTOM_LOCATION_ROOT_DIR or CT_ARCH_XTENSA_CUSTOM_OVERLAY_LOCATION must be set." \
        -z "${CT_CUSTOM_LOCATION_ROOT_DIR}" -a -z "${custom_location}"

    local full_file="${custom_location}/${custom_overlay}"
    local basename="${component}-${version}"
    local ext

    ext=${full_file/*./.}

    if [ -z "${ext}" ] ; then
        CT_DoLog WARN "'${full_file}' not found"
        return 1
    fi

    if [ -e "${CT_SRC_DIR}/.${basename}.configuring" ]; then
        CT_DoLog ERROR "The '${basename}' source were partially configured."
        CT_DoLog ERROR "Please remove first:"
        CT_DoLog ERROR " - the source dir for '${basename}', in '${CT_SRC_DIR}'"
        CT_DoLog ERROR " - the file '${CT_SRC_DIR}/.${basename}.extracted'"
        CT_DoLog ERROR " - the file '${CT_SRC_DIR}/.${basename}.patch'"
        CT_DoLog ERROR " - the file '${CT_SRC_DIR}/.${basename}.configuring'"
        CT_Abort
    fi

    CT_DoLog EXTRA "Using '${custom_overlay}' from ${custom_location}"
    CT_DoExecLog DEBUG ln -sf "${custom_location}/${custom_overlay}" \
                              "${CT_TARBALLS_DIR}/${custom_overlay}"

    CT_DoExecLog DEBUG touch "${CT_SRC_DIR}/.${basename}.configuring"

    CT_Pushd "${CT_SRC_DIR}/${basename}"

    tar_opts=( "--strip-components=1" )
    tar_opts+=( "-xv" )

    case "${ext}" in
        .tar)           CT_DoExecLog FILE tar "${tar_opts[@]}" -f "${full_file}" "${component}";;
        .gz|.tgz)       gzip -dc "${full_file}" | CT_DoExecLog FILE tar "${tar_opts[@]}" -f - "${component}";;
        .bz2)           bzip2 -dc "${full_file}" | CT_DoExecLog FILE tar "${tar_opts[@]}" -f - "${component}";;
        *)              CT_DoLog WARN "Don't know how to handle '${basename}${ext}': unknown extension"
                        return 1
                        ;;
    esac

    CT_DoExecLog DEBUG touch "${CT_SRC_DIR}/.${basename}.configured"
    CT_DoExecLog DEBUG rm -f "${CT_SRC_DIR}/.${basename}.configuring"

    CT_Popd
}
