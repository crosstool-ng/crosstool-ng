# Build script for D.U.M.A.

do_debug_duma_get() {
    local dl_base

    dl_base="http://downloads.sourceforge.net/project/duma/duma"
    dl_base+="/${CT_DUMA_VERSION//_/.}"

    # Downloading an non-existing file from sourceforge will give you an
    # HTML file containing an error message, instead of returning a 404.
    # Sigh...
    CT_GetFile "duma_${CT_DUMA_VERSION}" .tar.gz "${dl_base}"
    # Downloading from sourceforge may leave garbage, cleanup
    CT_DoExecLog ALL rm -f "${CT_TARBALLS_DIR}/showfiles.php"*
}

do_debug_duma_extract() {
    CT_Extract "duma_${CT_DUMA_VERSION}"
    CT_Pushd "${CT_SRC_DIR}/duma_${CT_DUMA_VERSION}"
    CT_Patch nochdir "duma" "${CT_DUMA_VERSION}"
    CT_Popd
}

do_debug_duma_build() {
    CT_DoStep INFO "Installing D.U.M.A."
    CT_DoLog EXTRA "Copying sources"
    cp -a "${CT_SRC_DIR}/duma_${CT_DUMA_VERSION}" "${CT_BUILD_DIR}/build-duma"
    CT_Pushd "${CT_BUILD_DIR}/build-duma"

    DUMA_CPP=
    [ "${CT_CC_LANG_CXX}" = "y" ] && DUMA_CPP=1

    # The shared library needs some love: some version have libduma.so.0.0,
    # while others have libduma.so.0.0.0
    duma_so=$(${make} -n -p 2>&1 |${grep} -E '^libduma.so[^:]*:' |head -n 1 |cut -d : -f 1)

    libs=
    [ "${CT_DUMA_A}" = "y" ] && libs="${libs} libduma.a"
    [ "${CT_DUMA_SO}" = "y" ] && libs="${libs} ${duma_so}"
    libs="${libs# }"
    CT_DoLog EXTRA "Building libraries '${libs}'"
    CT_DoExecLog ALL                    \
    ${make} HOSTCC="${CT_BUILD}-gcc"    \
         CC="${CT_TARGET}-gcc"          \
         CXX="${CT_TARGET}-gcc"         \
         RANLIB="${CT_TARGET}-ranlib"   \
         DUMA_CPP="${DUMA_CPP}"         \
         ${libs}
    CT_DoLog EXTRA "Installing libraries '${libs}'"
    CT_DoExecLog ALL ${install} -m 644 ${libs} "${CT_SYSROOT_DIR}/usr/lib"
    if [ "${CT_DUMA_SO}" = "y" ]; then
        CT_DoLog EXTRA "Installing shared library link"
        ln -vsf ${duma_so} "${CT_SYSROOT_DIR}/usr/lib/libduma.so"   2>&1 |CT_DoLog ALL
        CT_DoLog EXTRA "Installing wrapper script"
        mkdir -p "${CT_DEBUGROOT_DIR}/usr/bin"
        # Install a simpler, smaller, safer wrapper than the one provided by D.U.M.A.
        ${sed} -r -e 's:^LIBDUMA_SO=.*:LIBDUMA_SO=/usr/lib/'"${duma_so}"':;'   \
            "${CT_LIB_DIR}/scripts/build/debug/duma.in"                        \
            >"${CT_DEBUGROOT_DIR}/usr/bin/duma"
        chmod 755 "${CT_DEBUGROOT_DIR}/usr/bin/duma"
    fi

    CT_Popd
    CT_EndStep
}

