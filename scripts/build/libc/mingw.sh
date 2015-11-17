# Copyright 2012 Yann Diorcet
# Licensed under the GPL v2. See COPYING in the root of this package

CT_WINAPI_VERSION_DOWNLOADED=

do_libc_get() {
    CT_DoStep INFO "Fetching mingw-w64 source for ${CT_WINAPI_VERSION}"
    if [ "${CT_WINAPI_VERSION}" = "devel" ]; then
        CT_GetGit "mingw-w64" "ref=HEAD" "git://git.code.sf.net/p/mingw-w64/mingw-w64" CT_WINAPI_VERSION_DOWNLOADED
        CT_DoLog EXTRA "Fetched as ${CT_WINAPI_VERSION_DOWNLOADED}"
    else
        CT_GetFile "mingw-w64-v${CT_WINAPI_VERSION}" \
            http://downloads.sourceforge.net/sourceforge/mingw-w64
        CT_WINAPI_VERSION_DOWNLOADED=v${CT_WINAPI_VERSION}
    fi
    CT_EndStep
}

do_libc_extract() {
    CT_Extract "mingw-w64-${CT_WINAPI_VERSION_DOWNLOADED}"
    CT_Pushd "${CT_SRC_DIR}/mingw-w64-${CT_WINAPI_VERSION_DOWNLOADED}/"
    CT_Patch nochdir mingw-w64 "${CT_WINAPI_VERSION_DOWNLOADED}"
    CT_Popd
}

do_libc_check_config() {
    :
}

do_set_mingw_install_prefix(){
    MINGW_INSTALL_PREFIX=/usr/${CT_TARGET}
    if [[ ${CT_WINAPI_VERSION} == 2* ]]; then
        MINGW_INSTALL_PREFIX=/usr
    fi
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

    do_set_mingw_install_prefix
    CT_DoExecLog CFG        \
    "${CT_SRC_DIR}/mingw-w64-${CT_WINAPI_VERSION_DOWNLOADED}/mingw-w64-headers/configure" \
        --build=${CT_BUILD} \
        --host=${CT_TARGET} \
        --prefix=${MINGW_INSTALL_PREFIX} \
        "${sdk_opts[@]}"

    CT_DoLog EXTRA "Compile Headers"
    CT_DoExecLog ALL ${make}

    CT_DoLog EXTRA "Installing Headers"
    CT_DoExecLog ALL ${make} install DESTDIR=${CT_SYSROOT_DIR}

    CT_Popd

    # It seems mingw is strangely set up to look into /mingw instead of
    # /usr (notably when looking for the headers). This symlink is
    # here to workaround this, and seems to be here to last... :-/
    CT_DoExecLog ALL ln -sv "usr/${CT_TARGET}" "${CT_SYSROOT_DIR}/mingw"

    CT_EndStep
}

do_check_mingw_vendor_tuple()
{
    if [[ ${CT_WINAPI_VERSION} == 4* ]]; then
       CT_DoStep INFO "Checking vendor tuple configured in crosstool-ng .config"
       if [[ ${CT_TARGET_VENDOR} == w64 ]]; then
           CT_DoLog EXTRA "The tuple is set to '${CT_TARGET_VENDOR}', as recommended by mingw-64 team."
       else
           CT_DoLog WARN "WARNING! The tuple '${CT_TARGET_VENDOR}', is not equal to w64 and might break the toolchain! WARNING!"
       fi
       CT_EndStep
    fi
}

do_libc() {
    do_check_mingw_vendor_tuple

    CT_DoStep INFO "Building mingw-w64 files"

    CT_DoLog EXTRA "Configuring mingw-w64-crt"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mingw-w64-crt"

    do_set_mingw_install_prefix
    CT_DoExecLog CFG                                                                  \
    "${CT_SRC_DIR}/mingw-w64-${CT_WINAPI_VERSION_DOWNLOADED}/mingw-w64-crt/configure" \
        --with-sysroot=${CT_SYSROOT_DIR}                                              \
        --prefix=${MINGW_INSTALL_PREFIX}                                              \
        --build=${CT_BUILD}                                                           \
        --host=${CT_TARGET}                                                           \

    # mingw-w64-crt has a missing dependency occasionally breaking the
    # parallel build. See https://github.com/crosstool-ng/crosstool-ng/issues/246
    # Do not pass ${JOBSFLAGS} - build serially.
    CT_DoLog EXTRA "Building mingw-w64-crt"
    CT_DoExecLog ALL ${make}

    CT_DoLog EXTRA "Installing mingw-w64-crt"
    CT_DoExecLog ALL ${make} install DESTDIR=${CT_SYSROOT_DIR}

    CT_EndStep
}

do_libc_post_cc() {
    :
}
