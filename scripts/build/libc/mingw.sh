# Copyright 2012 Yann Diorcet
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() { 
    CT_GetFile "mingw-w64-v${CT_WINAPI_VERSION}" \
        http://downloads.sourceforge.net/sourceforge/mingw-w64
}

do_libc_extract() {
    CT_Extract "mingw-w64-v${CT_WINAPI_VERSION}"
    CT_Pushd "${CT_SRC_DIR}/mingw-w64-v${CT_WINAPI_VERSION}/"
    CT_Patch nochdir mingw-w64 "${CT_WINAPI_VERSION}"
    CT_Popd
}

do_libc_check_config() {
    :
}

do_libc_start_files() {
    local -a sdk_opts

    CT_DoStep INFO "Installing C library headers"

    case "${CT_MINGW_DIRECTX}:${CT_MINGW_DDK}" in
        y:y)    sdk_opts+=( "--enable-sdk=all"     );;
        y:)     sdk_opts+=( "--enable-sdk=directx" );;
        :y)     sdk_opts+=( "--enable-sdk=ddk"     );;
        :)      ;;
    esac

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mingw-w64-headers"

    CT_DoLog EXTRA "Configuring Headers"

    CT_DoExecLog CFG        \
    "${CT_SRC_DIR}/mingw-w64-v${CT_WINAPI_VERSION}/mingw-w64-headers/configure" \
        --build=${CT_BUILD} \
        --host=${CT_TARGET} \
        --prefix=/usr       \
        "${sdk_opts[@]}"

    CT_DoLog EXTRA "Compile Headers"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing Headers"
    CT_DoExecLog ALL make install DESTDIR=${CT_SYSROOT_DIR}
    
    CT_Popd

    # It seems mingw is strangely set up to look into /mingw instead of
    # /usr (notably when looking for the headers). This symlink is
    # here to workaround this, and seems to be here to last... :-/
    CT_DoExecLog ALL ln -sv "usr/${CT_TARGET}" "${CT_SYSROOT_DIR}/mingw"

    CT_EndStep
}

do_libc() {
    CT_DoStep INFO "Building mingw-w64 files"

    CT_DoLog EXTRA "Configuring mingw-w64-crt"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mingw-w64-crt"

    CT_DoExecLog CFG                                                        \
    "${CT_SRC_DIR}/mingw-w64-v${CT_WINAPI_VERSION}/mingw-w64-crt/configure" \
        --prefix=/usr                                                       \
        --build=${CT_BUILD}                                                 \
        --host=${CT_TARGET}                                                 \

    CT_DoLog EXTRA "Building mingw-w64-crt"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing mingw-w64-crt"
    CT_DoExecLog ALL make install DESTDIR=${CT_SYSROOT_DIR}

    CT_EndStep
}
