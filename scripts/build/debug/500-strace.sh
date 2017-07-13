# Build script for strace

do_debug_strace_get() {
    CT_Fetch STRACE
}

do_debug_strace_extract() {
    CT_ExtractPatch STRACE
}

do_debug_strace_build() {
    CT_DoStep INFO "Installing strace"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-strace"

    CT_DoLog EXTRA "Configuring strace"
    CT_DoExecLog CFG                                           \
    CC="${CT_TARGET}-${CT_CC}"                                 \
    CPP="${CT_TARGET}-cpp"                                     \
    LD="${CT_TARGET}-ld"                                       \
    ${CONFIG_SHELL}                                            \
    "${CT_SRC_DIR}/strace/configure"                           \
        --build=${CT_BUILD}                                    \
        --host=${CT_TARGET}                                    \
        --prefix=/usr

    CT_DoLog EXTRA "Building strace"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing strace"
    CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

    CT_Popd
    CT_EndStep
}

