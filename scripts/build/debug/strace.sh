# Build script for strace

is_enabled="${CT_STRACE}"

do_print_filename() {
    [ "${CT_STRACE}" = "y" ] || return 0
    echo "strace-${CT_STRACE_VERSION}"
}

do_debug_strace_get() {
    CT_GetFile "strace-${CT_STRACE_VERSION}" http://mesh.dl.sourceforge.net/sourceforge/strace/
}

do_debug_strace_extract() {
    CT_ExtractAndPatch "strace-${CT_STRACE_VERSION}"
}

do_debug_strace_build() {
    CT_DoStep INFO "Installing strace"
    mkdir -p "${CT_BUILD_DIR}/build-strace"
    CT_Pushd "${CT_BUILD_DIR}/build-strace"

    CT_DoLog EXTRA "Configuring strace"
    "${CT_SRC_DIR}/strace-${CT_STRACE_VERSION}/configure"   \
        --build=${CT_BUILD}                                 \
        --host=${CT_TARGET}                                 \
        --prefix=/usr                                       2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Building strace"
    make    2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing strace"
    make DESTDIR="${CT_DEBUG_INSTALL_DIR}" install  2>&1 |CT_DoLog ALL

    CT_Popd
    CT_EndStep
}

