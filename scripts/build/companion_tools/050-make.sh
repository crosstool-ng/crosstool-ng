# Build script for make

CT_MAKE_VERSION=3.81

do_companion_tools_make_get() {
    CT_GetFile "make-${CT_MAKE_VERSION}"        \
        {http,ftp,https}://ftp.gnu.org/gnu/make
}

do_companion_tools_make_extract() {
    CT_Extract "make-${CT_MAKE_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/make-${CT_MAKE_VERSION}"
    CT_Patch "make" "${CT_MAKE_VERSION}"
}

do_companion_tools_make_build() {
    CT_DoStep EXTRA "Installing make"
    mkdir -p "${CT_BUILD_DIR}/build-make"
    CT_Pushd "${CT_BUILD_DIR}/build-make"

    CT_DoExecLog CFG "${CT_SRC_DIR}/make-${CT_MAKE_VERSION}/configure" \
                     --prefix="${CT_BUILDTOOLS_PREFIX_DIR}"
    CT_DoExecLog ALL ${make}
    CT_DoExecLog ALL ${make} install
    if [ "${CT_COMP_TOOLS_make_gmake}" = "y" ]; then
        CT_DoExecLog ALL ln -sv ${make} "${CT_BUILDTOOLS_PREFIX_DIR}/bin/gmake"
    fi
    CT_Popd
    CT_EndStep
}
