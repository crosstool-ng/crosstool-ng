# Build script for ltrace

do_debug_ltrace_get() {
    CT_GetFile "ltrace_${CT_LTRACE_VERSION}.orig" .tar.gz               \
               {http,ftp}://ftp.debian.org/debian/pool/main/l/ltrace/
    # Create a link so that the following steps are easier to do:
    CT_Pushd "${CT_TARBALLS_DIR}"
    ltrace_ext=$(CT_GetFileExtension "ltrace_${CT_LTRACE_VERSION}.orig")
    ln -sf "ltrace_${CT_LTRACE_VERSION}.orig${ltrace_ext}"              \
           "ltrace-${CT_LTRACE_VERSION}${ltrace_ext}"
    CT_Popd
}

do_debug_ltrace_extract() {
    CT_Extract "ltrace-${CT_LTRACE_VERSION}"
    CT_Patch "ltrace" "${CT_LTRACE_VERSION}"
}

do_debug_ltrace_build() {
    local ltrace_host

    CT_DoStep INFO "Installing ltrace"

    CT_DoLog EXTRA "Copying sources to build dir"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/ltrace-${CT_LTRACE_VERSION}" \
                            "${CT_BUILD_DIR}/build-ltrace"
    CT_Pushd "${CT_BUILD_DIR}/build-ltrace"

    CT_DoLog EXTRA "Configuring ltrace"
    # ltrace-0.5.3, and later, don't use GNU Autotools configure script anymore
    if [ "${CT_LTRACE_0_5_3_or_later}" = "y" ]; then
        case "${CT_ARCH}:${CT_ARCH_BITNESS}" in
            x86:32)     ltrace_host="i386";;
            x86:64)     ltrace_host="x86_64";;
            powerpc:*)  ltrace_host="ppc";;
            mips:*)     ltrace_host="mipsel";;
            *)          ltrace_host="${CT_ARCH}";;
        esac
        CT_DoExecLog CFG                \
        CC="${CT_TARGET}-${CT_CC}"      \
        AR="${CT_TARGET}-ar"            \
        HOST="${ltrace_host}"           \
        HOST_OS="${CT_TARGET_KERNEL}"   \
        CFLAGS="${CT_TARGET_CFLAGS}"    \
        ./configure --prefix=/usr
    else
        CT_DoExecLog CFG        \
        ./configure             \
            --build=${CT_BUILD} \
            --host=${CT_TARGET} \
            --prefix=/usr
    fi

    CT_DoLog EXTRA "Building ltrace"
    CT_DoExecLog ALL ${make}

    CT_DoLog EXTRA "Installing ltrace"
    CT_DoExecLog ALL ${make} DESTDIR="${CT_DEBUGROOT_DIR}" install

    CT_Popd
    CT_EndStep
}

