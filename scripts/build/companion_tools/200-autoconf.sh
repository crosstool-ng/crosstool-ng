# Build script for autoconf

CT_AUTOCONF_VERSION=2.65

do_companion_tools_autoconf_get() {
    CT_GetFile "autoconf-${CT_AUTOCONF_VERSION}"    \
        {http,ftp,https}://ftp.gnu.org/gnu/autoconf
}

do_companion_tools_autoconf_extract() {
    CT_Extract "autoconf-${CT_AUTOCONF_VERSION}"
    CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/autoconf-${CT_AUTOCONF_VERSION}"
    CT_Patch "autoconf" "${CT_AUTOCONF_VERSION}"
}

do_companion_tools_autoconf_build() {
    CT_DoStep EXTRA "Installing autoconf"
    mkdir -p "${CT_BUILD_DIR}/build-autoconf"
    CT_Pushd "${CT_BUILD_DIR}/build-autoconf"
    
    # Ensure configure gets run using the CONFIG_SHELL as configure seems to
    # have trouble when CONFIG_SHELL is set and /bin/sh isn't bash
    # For reference see:
    # http://www.gnu.org/software/autoconf/manual/autoconf.html#CONFIG_005fSHELL
    
    CT_DoExecLog CFG ${CONFIG_SHELL} \
    "${CT_SRC_DIR}/autoconf-${CT_AUTOCONF_VERSION}/configure" \
        --prefix="${CT_BUILDTOOLS_PREFIX_DIR}"
    CT_DoExecLog ALL ${make}
    CT_DoExecLog ALL ${make} install
    CT_Popd
    CT_EndStep
}
