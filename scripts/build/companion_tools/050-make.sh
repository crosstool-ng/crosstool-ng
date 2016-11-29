# Build script for make

do_companion_tools_make_get() {
    CT_GetFile "make-${CT_MAKE_VERSION}"        \
        {http,ftp,https}://ftp.gnu.org/gnu/make
}

do_companion_tools_make_extract() {
    CT_Extract "make-${CT_MAKE_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/make-${CT_MAKE_VERSION}"
    CT_Patch "make" "${CT_MAKE_VERSION}"
}

do_companion_tools_make_for_build() {
    CT_DoStep EXTRA "Installing make for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-make-build"
    do_make_backend \
        host=${CT_BUILD} \
        prefix="${CT_BUILD_COMPTOOLS_DIR}" \
        cflags="${CT_CFLAGS_FOR_BUILD}" \
        ldflags="${CT_LDFLAGS_FOR_BUILD}"
    CT_Popd
    if [ "${CT_MAKE_GMAKE_SYMLINK}" = "y" ]; then
        CT_DoExecLog ALL ln -sv make "${CT_BUILD_COMPTOOLS_DIR}/bin/gmake"
    fi
    CT_EndStep
}

do_companion_tools_make_for_host() {
    CT_DoStep EXTRA "Installing make for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-make-host"
    do_make_backend \
        host=${CT_HOST} \
        prefix="${CT_PREFIX_DIR}" \
        cflags="${CT_CFLAGS_FOR_HOST}" \
        ldflags="${CT_LDFLAGS_FOR_HOST}"
    CT_Popd
    if [ "${CT_MAKE_GMAKE_SYMLINK}" = "y" ]; then
        CT_DoExecLog ALL ln -sv make "${CT_PREFIX_DIR}/bin/gmake"
    fi
    CT_EndStep
}

do_make_backend() {
    local host
    local prefix
    local cflags
    local ldflags

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring make"
    CT_DoExecLog CFG \
                     CFLAGS="${cflags}" \
                     LDFLAGS="${ldflags}" \
                     "${CT_SRC_DIR}/make-${CT_MAKE_VERSION}/configure" \
                     --host="${host}" \
                     --prefix="${prefix}"

    CT_DoLog EXTRA "Building make"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing make"
    CT_DoExecLog ALL make install
}
