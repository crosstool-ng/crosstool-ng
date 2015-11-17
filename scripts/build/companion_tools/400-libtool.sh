# Build script for libtool

CT_LIBTOOL_VERSION=2.4.6

do_companion_tools_libtool_get() {
    CT_GetFile "libtool-${CT_LIBTOOL_VERSION}"     \
        {http,ftp,https}://ftp.gnu.org/gnu/libtool
}

do_companion_tools_libtool_extract() {
    CT_Extract "libtool-${CT_LIBTOOL_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/libtool-${CT_LIBTOOL_VERSION}"
    CT_Patch "libtool" "${CT_LIBTOOL_VERSION}"
}

do_companion_tools_libtool_build() {
    CT_DoStep EXTRA "Installing libtool"
    mkdir -p "${CT_BUILD_DIR}/build-libtool"
    CT_Pushd "${CT_BUILD_DIR}/build-libtool"
    
    CT_DoExecLog CFG \
    "${CT_SRC_DIR}/libtool-${CT_LIBTOOL_VERSION}/configure" \
        --prefix="${CT_BUILDTOOLS_PREFIX_DIR}"
    CT_DoExecLog ALL ${make}
    CT_DoExecLog ALL ${make} install
    CT_Popd
    CT_EndStep
}
