# Build script for automake

CT_AUTOMAKE_VERSION=1.11.1

do_companion_tools_automake_get() {
    CT_GetFile "automake-${CT_AUTOMAKE_VERSION}"    \
        {http,ftp,https}://ftp.gnu.org/gnu/automake
}

do_companion_tools_automake_extract() {
    CT_Extract "automake-${CT_AUTOMAKE_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/automake-${CT_AUTOMAKE_VERSION}"
    CT_Patch "automake" "${CT_AUTOMAKE_VERSION}"
}

do_companion_tools_automake_build() {
    CT_DoStep EXTRA "Installing automake"
    mkdir -p "${CT_BUILD_DIR}/build-automake"
    CT_Pushd "${CT_BUILD_DIR}/build-automake"
    
    CT_DoExecLog CFG \
    "${CT_SRC_DIR}/automake-${CT_AUTOMAKE_VERSION}/configure" \
        --prefix="${CT_BUILDTOOLS_PREFIX_DIR}"
    CT_DoExecLog ALL ${make}
    CT_DoExecLog ALL ${make} install
    CT_Popd
    CT_EndStep
}
