# Biuld script for D.U.M.A.

is_enabled="${CT_DUMA}"

do_print_filename() {
    [ "${CT_DUMA}" = "y" ] || return 0
    echo "duma_${CT_DUMA_VERSION}"
}

do_debug_duma_get() {
    CT_GetFile "duma_${CT_DUMA_VERSION}" http://mesh.dl.sourceforge.net/sourceforge/duma/
    # D.U.M.A. doesn't separate its name from its version with a dash,
    # but with an underscore. Create a link so that crosstool-NG can
    # work correctly:
    cd "${CT_TARBALLS_DIR}"
    duma_ext=$(CT_GetFileExtension "duma_${CT_DUMA_VERSION}")
    rm -f "duma-${CT_DUMA_VERSION}${duma_ext}"
    ln -sf "duma_${CT_DUMA_VERSION}${duma_ext}" "duma-${CT_DUMA_VERSION}${duma_ext}"
}

do_debug_duma_extract() {
    CT_ExtractAndPatch "duma-${CT_DUMA_VERSION}"
    cd "${CT_SRC_DIR}"
    rm -f "duma-${CT_DUMA_VERSION}"
    ln -sf "duma_${CT_DUMA_VERSION}" "duma-${CT_DUMA_VERSION}"
}

do_debug_duma_build() {
    CT_DoStep INFO "Installing D.U.M.A."
    CT_DoLog EXTRA "Copying sources"
    cp -a "${CT_SRC_DIR}/duma_${CT_DUMA_VERSION}" "${CT_BUILD_DIR}/build-duma"
    CT_Pushd "${CT_BUILD_DIR}/build-duma"

    DUMA_CPP=
    [ "${CT_CC_LANG_CXX}" = "y" ] && DUMA_CPP=1

    libs=
    [ "${CT_DUMA_A}" = "y" ] && libs="${libs} libduma.a"
    [ "${CT_DUMA_SO}" = "y" ] && libs="${libs} libduma.so.0.0"
    for lib in ${libs}; do
        CT_DoLog EXTRA "Building library '${lib}'"
        make HOSTCC="${CT_CC_NATIVE}"       \
             HOSTCXX="${CT_CC_NATIVE}"      \
             CC="${CT_TARGET}-${CT_CC}"     \
             CXX="${CT_TARGET}-${CT_CC}"    \
             DUMA_CPP="${DUMA_CPP}"         \
             ${libs}                        2>&1 |CT_DoLog ALL
        CT_DoLog EXTRA "Installing library '${lib}'"
        install -m 644 "${lib}" "${CT_SYSROOT_DIR}/usr/lib" 2>&1 |CT_DoLog ALL
    done
    if [ "${CT_DUMA_SO}" = "y" ]; then
        CT_DoLog EXTRA "Installing shared library links"
        ln -vsf libduma.so.0.0 "${CT_SYSROOT_DIR}/usr/lib/libduma.so.0" 2>&1 |CT_DoLog ALL
        ln -vsf libduma.so.0.0 "${CT_SYSROOT_DIR}/usr/lib/libduma.so"   2>&1 |CT_DoLog ALL
    fi
    CT_DoLog EXTRA "Installing LD_PRELOAD wrapper script"
    mkdir -p "${CT_DEBUG_INSTALL_DIR}/usr/bin"
    cp -v duma.sh                               \
       "${CT_DEBUG_INSTALL_DIR}/usr/bin/duma"   2>&1 |CT_DoLog ALL

    CT_EndStep
    CT_Popd
}

