# Build script for libtool

CT_LIBTOOL_VERSION=2.2.6b

do_companion_tools_libtool_get() {
    CT_GetFile "libtool-${CT_LIBTOOL_VERSION}" \
               {ftp,http}://ftp.gnu.org/gnu/libtool
}

do_companion_tools_libtool_extract() {
    CT_Extract "libtool-${CT_LIBTOOL_VERSION}"
    CT_Patch "libtool-${CT_LIBTOOL_VERSION}"
}

do_companion_tools_libtool_build() {
    CT_DoStep EXTRA "Installing libtool"
    mkdir -p "${CT_BUILD_DIR}/build-libtool"
    CT_Pushd "${CT_BUILD_DIR}/build-libtool"
    
    CT_DoExecLog ALL \
    "${CT_SRC_DIR}/libtool-${CT_LIBTOOL_VERSION}/configure" \
        --prefix="${CT_TOOLS_OVERIDE_DIR}"
    CT_DoExecLog ALL make
    CT_DoExecLog ALL make install
    CT_Popd
    CT_EndStep
}
