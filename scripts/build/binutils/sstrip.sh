# This will build and install sstrip to run on host and sstrip target files

do_tools_sstrip_get() { :; }
do_tools_sstrip_extract() { :; }
do_tools_sstrip() { :; }

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

    do_sstrip() {
        CT_DoStep INFO "Installing sstrip"
        mkdir -p "${CT_BUILD_DIR}/build-sstrip"
        cd "${CT_BUILD_DIR}/build-sstrip"

        CT_DoLog EXTRA "Building sstrip"
        CT_DoExecLog ALL "${CT_HOST}-gcc" -Wall -o sstrip "${CT_SRC_DIR}/sstrip/sstrip.c"

        CT_DoLog EXTRA "Installing sstrip"
        CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

        CT_EndStep
    }
fi
