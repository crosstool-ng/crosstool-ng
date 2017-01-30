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
    local -a make_args

    CT_DoStep INFO "Installing D.U.M.A."
    CT_DoLog EXTRA "Copying sources"
    cp -a "${CT_SRC_DIR}/duma_${CT_DUMA_VERSION}/." "${CT_BUILD_DIR}/build-duma"
    CT_Pushd "${CT_BUILD_DIR}/build-duma"

    make_args=(
        prefix="${CT_DEBUGROOT_DIR}/usr"
        HOSTCC="${CT_BUILD}-gcc"
        CC="${CT_TARGET}-${CT_CC}"
        CXX="${CT_TARGET}-g++"
        RANLIB="${CT_TARGET}-ranlib"
        OS="${CT_KERNEL}"
    )
    [ "${CT_CC_LANG_CXX}" = "y" ] && make_args+=( DUMA_CPP=1 )
    [ "${CT_DUMA_SO}" = "y" ] || make_args+=( DUMASO= )

    CT_DoLog EXTRA "Building D.U.M.A"
    CT_DoExecLog ALL make "${make_args[@]}" all
    CT_DoLog EXTRA "Installing D.U.M.A"
    CT_DoExecLog ALL make "${make_args[@]}" install

    if [ "${CT_DUMA_CUSTOM_WRAPPER}" = "y" ]; then
        # The shared library needs some love: some version have libduma.so.0.0,
        # while others have libduma.so.0.0.0
        duma_so=$( make "${make_args[@]}" printvars | sed -n -r -e 's/^DUMASO \[(.*)\]$/\1/p' )

        CT_DoLog EXTRA "Installing wrapper script"
        CT_DoExecLog ALL mkdir -p "${CT_DEBUGROOT_DIR}/usr/bin"
        # Install a simpler, smaller, safer wrapper than the one provided by D.U.M.A.
        CT_DoExecLog ALL rm -f "${CT_DEBUGROOT_DIR}/usr/bin/duma"
        CT_DoExecLog ALL cp "${CT_LIB_DIR}/scripts/build/debug/duma.in" \
                            "${CT_DEBUGROOT_DIR}/usr/bin/duma"
        CT_DoExecLog ALL sed -i -r -e "s:^LIBDUMA_SO=.*:LIBDUMA_SO=/usr/lib/${duma_so}:;" \
                            "${CT_DEBUGROOT_DIR}/usr/bin/duma"
        CT_DoExecLog ALL chmod 755 "${CT_DEBUGROOT_DIR}/usr/bin/duma"
    fi

    CT_Popd
    CT_EndStep
}

