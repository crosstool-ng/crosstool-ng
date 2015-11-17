# Build script for m4

CT_M4_VERSION=1.4.13

do_companion_tools_m4_get() {
    CT_GetFile "m4-${CT_M4_VERSION}"          \
        {http,ftp,https}://ftp.gnu.org/gnu/m4
}

do_companion_tools_m4_extract() {
    CT_Extract "m4-${CT_M4_VERSION}"
    CT_Patch "m4" "${CT_M4_VERSION}"
}

do_companion_tools_m4_build() {
    CT_DoStep EXTRA "Installing m4"
    mkdir -p "${CT_BUILD_DIR}/build-m4"
    CT_Pushd "${CT_BUILD_DIR}/build-m4"
    
    CT_DoExecLog CFG \
    "${CT_SRC_DIR}/m4-${CT_M4_VERSION}/configure" \
        --prefix="${CT_BUILDTOOLS_PREFIX_DIR}"
    CT_DoExecLog ALL ${make}
    CT_DoExecLog ALL ${make} install
    CT_Popd
    CT_EndStep
}
