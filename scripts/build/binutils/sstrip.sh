# This will build and install sstrip to run on host and sstrip target files

do_sstrip_get()      { :; }
do_sstrip_extract()  { :; }
do_sstrip_for_host() { :; }

if [ "${CT_SSTRIP}" = "y" ]; then
    do_sstrip_get() {
        CT_GetFile sstrip .c http://git.buildroot.net/buildroot/plain/toolchain/sstrip
    }

    do_sstrip_extract() {
        # We leave the sstrip maintenance to the buildroot people:
        # -> any fix-up goes directly there
        # -> we don't have patches for it
        # -> we don't need to patch it
        # -> just create a directory in src/, and copy it there.
        CT_DoExecLog DEBUG mkdir -p "${CT_SRC_DIR}/sstrip"
        CT_DoExecLog DEBUG cp -v "${CT_TARBALLS_DIR}/sstrip.c" "${CT_SRC_DIR}/sstrip"
    }

    # Build sstrip for host -> target
    # Note: we don't need sstrip to run on the build machine,
    # so we do not need the frontend/backend stuff...
    do_sstrip_for_host() {
        local sstrip_cflags
        CT_DoStep INFO "Installing sstrip for host"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-sstrip-host"

        if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
            sstrip_cflags="-static"
        fi

        CT_DoLog EXTRA "Building sstrip"
        CT_DoExecLog ALL "${CT_HOST}-gcc" -Wall ${sstrip_cflags} -o sstrip "${CT_SRC_DIR}/sstrip/sstrip.c"

        CT_DoLog EXTRA "Installing sstrip"
        CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

        CT_Popd
        CT_EndStep
    }
fi
