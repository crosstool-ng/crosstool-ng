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

    # Strace needs _IOC definitions, and it tries to pick them up from <linux/ioctl.h>.
    # While cross-compiling on a non-Linux host, we don't have this header. Replacing
    # <linux/ioctl.h> with <sys/ioctl.h>, as suggested by many internet "solutions",
    # is wrong: for example, MacOS defines _IOC macros differently, and we need the
    # definitions for the target!
    # Hence, create a "window" into target includes.
    CT_DoExecLog ALL mkdir -p "${CT_BUILD_DIR}/build-strace-headers"
    for d in linux asm asm-generic; do
        CT_DoExecLog ALL ln -sf "${CT_HEADERS_DIR}/${d}" "${CT_BUILD_DIR}/build-strace-headers/${d}"
    done

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-strace"

    CT_DoLog EXTRA "Configuring strace"
    CT_DoExecLog CFG                                           \
    CFLAGS_FOR_BUILD="-I ${CT_BUILD_DIR}/build-strace-headers" \
    CC="${CT_TARGET}-${CT_CC}"                                 \
    CPP="${CT_TARGET}-cpp"                                     \
    LD="${CT_TARGET}-ld"                                       \
    "${CT_SRC_DIR}/strace-${CT_STRACE_VERSION}/configure"      \
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

