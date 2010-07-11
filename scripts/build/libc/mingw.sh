do_libc_get() {
    CT_GetFile "mingwrt-${CT_MINGWRT_VERSION}-mingw32-src" \
        http://downloads.sourceforge.net/sourceforge/mingw
}

do_libc_extract() {
    CT_Extract "mingwrt-${CT_MINGWRT_VERSION}-mingw32-src"
}

do_libc_check_config() {
    :
}

do_libc_headers() {
    CT_DoStep INFO "Installing C library headers"

    CT_DoLog EXTRA "Installing MinGW Runtime headers"
    mkdir -p "${CT_SYSROOT_DIR}/include"
    cp -r ${CT_SRC_DIR}/mingwrt-${CT_MINGWRT_VERSION}-mingw32/include \
          ${CT_SYSROOT_DIR}

    CT_EndStep
}

do_libc_start_files() {
    :
}

do_libc() {
    CT_DoStep INFO "Building MinGW files"

    CT_DoLog EXTRA "Configuring W32-API"

    mkdir -p "${CT_BUILD_DIR}/build-w32api"
    cd "${CT_BUILD_DIR}/build-w32api"

    CFLAGS="-I${CT_SYSROOT_DIR}/include"                          \
    LDFLAGS="-L${CT_SYSROOT_DIR}/lib"                             \
    CT_DoExecLog ALL                                              \
    "${CT_SRC_DIR}/w32api-${CT_W32API_VERSION}-mingw32/configure" \
        --prefix=${CT_SYSROOT_DIR}                                \
        --host=${CT_TARGET}

    CT_DoLog EXTRA "Building W32-API"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    CT_DoLog EXTRA "Installing W32-API"
    CT_DoExecLog ALL make install

    CT_DoLog EXTRA "Configuring MinGW Runtime"

    mkdir -p "${CT_BUILD_DIR}/build-mingwrt"
    cd "${CT_BUILD_DIR}/build-mingwrt"

    CFLAGS="-I${CT_SYSROOT_DIR}/include"                            \
    LDFLAGS="-L${CT_SYSROOT_DIR}/lib"                               \
    CT_DoExecLog ALL                                                \
    "${CT_SRC_DIR}/mingwrt-${CT_MINGWRT_VERSION}-mingw32/configure" \
        --prefix=${CT_SYSROOT_DIR}/                                 \
        --host=${CT_TARGET}

    CT_DoLog EXTRA "Building MinGW Runtime"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    CT_DoLog EXTRA "Installing MinGW Runtime"
    CT_DoExecLog ALL make install

    CT_EndStep
}

do_libc_finish() {
 :
}

