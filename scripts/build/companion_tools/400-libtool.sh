# Build script for libtool

do_companion_tools_libtool_get() {
    CT_GetFile "libtool-${CT_LIBTOOL_VERSION}"     \
        {http,ftp,https}://ftp.gnu.org/gnu/libtool
}

do_companion_tools_libtool_extract() {
    CT_Extract "libtool-${CT_LIBTOOL_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/libtool-${CT_LIBTOOL_VERSION}"
    CT_Patch "libtool" "${CT_LIBTOOL_VERSION}"
}

do_companion_tools_libtool_for_build() {
    CT_DoStep EXTRA "Installing libtool for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libtool-build"
    do_libtool_backend host=${CT_BUILD} prefix="${CT_BUILD_COMPTOOLS_DIR}"
    CT_Popd
    CT_EndStep
}

do_companion_tools_libtool_for_host() {
    CT_DoStep EXTRA "Installing libtool for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libtool-host"
    do_libtool_backend host=${CT_HOST} prefix="${CT_PREFIX_DIR}"
    CT_Popd
    CT_EndStep
}

do_libtool_backend() {
    local host
    local prefix

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring libtool"
    CT_DoExecLog CFG "${CT_SRC_DIR}/libtool-${CT_LIBTOOL_VERSION}/configure" \
                     --host="${host}" \
                     --prefix="${prefix}"

    CT_DoLog EXTRA "Building libtool"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing libtool"
    CT_DoExecLog ALL make install
}
