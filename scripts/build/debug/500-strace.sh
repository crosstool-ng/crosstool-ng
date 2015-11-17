# Build script for strace

do_debug_strace_get() {
    local base_url="http://downloads.sourceforge.net/project/strace/strace"
    CT_GetFile "strace-${CT_STRACE_VERSION}" "${base_url}/${CT_STRACE_VERSION}"
    # Downloading from sourceforge leaves garbage, cleanup
    CT_DoExecLog ALL rm -f "${CT_TARBALLS_DIR}/showfiles.php"*
}

do_debug_strace_extract() {
    CT_Extract "strace-${CT_STRACE_VERSION}"
    CT_Patch "strace" "${CT_STRACE_VERSION}"
}

do_debug_strace_build() {
    CT_DoStep INFO "Installing strace"
    mkdir -p "${CT_BUILD_DIR}/build-strace"
    CT_Pushd "${CT_BUILD_DIR}/build-strace"

    CT_DoLog EXTRA "Configuring strace"
    CT_DoExecLog CFG                                        \
    CC="${CT_TARGET}-gcc"                                   \
    CPP="${CT_TARGET}-cpp"                                  \
    LD="${LD_TARGET}-ld"                                    \
    "${CT_SRC_DIR}/strace-${CT_STRACE_VERSION}/configure"   \
        --build=${CT_BUILD}                                 \
        --host=${CT_TARGET}                                 \
        --prefix=/usr

    CT_DoLog EXTRA "Building strace"
    CT_DoExecLog ALL ${make}

    CT_DoLog EXTRA "Installing strace"
    CT_DoExecLog ALL ${make} DESTDIR="${CT_DEBUGROOT_DIR}" install

    CT_Popd
    CT_EndStep
}

