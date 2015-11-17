# This file adds functions to build the avr-libc C library

do_libc_get() {
    local libc_src

    libc_src="http://download.savannah.gnu.org/releases/avr-libc"

    if [ "${CT_LIBC_AVR_LIBC_CUSTOM}" = "y" ]; then
        CT_GetCustom "avr-libc" "${CT_LIBC_VERSION}"      \
                     "${CT_LIBC_AVR_LIBC_CUSTOM_LOCATION}"
    else # ! custom location
        CT_GetFile "avr-libc-${CT_LIBC_VERSION}" "${libc_src}"
    fi # ! custom location
}

do_libc_extract() {
    # If using custom directory location, nothing to do.
    if [ "${CT_LIBC_AVR_LIBC_CUSTOM}" = "y" ]; then
        # Abort if the custom directory is not found.
        if ! [ -d "${CT_SRC_DIR}/avr-libc-${CT_LIBC_VERSION}" ]; then
            CT_Abort "Directory not found: ${CT_SRC_DIR}/avr-libc-${CT_LIBC_VERSION}"
        fi

        return 0
    fi

    CT_Extract "avr-libc-${CT_LIBC_VERSION}"
    CT_Patch "avr-libc" "${CT_LIBC_VERSION}"
}

do_libc_check_config() {
    :
}

do_libc_configure() {
    CT_DoLog EXTRA "Configuring C library"

    CT_DoExecLog CFG                \
    ./configure                     \
        --build=${CT_BUILD}         \
        --host=${CT_TARGET}         \
        --prefix=${CT_PREFIX_DIR}   \
        "${CT_LIBC_AVR_LIBC_EXTRA_CONFIG_ARRAY[@]}"
}

do_libc_start_files() {
    :
}

do_libc() {
    :
}

do_libc_post_cc() {
    CT_DoStep INFO "Installing C library"

    CT_DoLog EXTRA "Copying sources to build directory"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/avr-libc-${CT_LIBC_VERSION}" \
                            "${CT_BUILD_DIR}/build-libc-post-cc"
    cd "${CT_BUILD_DIR}/build-libc-post-cc"

    do_libc_configure

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL ${make} install

    CT_EndStep
}
