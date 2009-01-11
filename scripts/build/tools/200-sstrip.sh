# This will build and install sstrip to run on host and sstrip target files

case "${CT_SSTRIP_FROM}" in
    ELFkickers)
        do_tools_sstrip_get() {
            CT_GetFile "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"     \
                       http://www.muppetlabs.com/~breadbox/pub/software
        }
        do_tools_sstrip_extract() {
            CT_Extract "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"
            CT_Patch "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"
        }
        do_tools_sstrip_build() {
            CT_DoStep INFO "Installing sstrip"
            mkdir -p "${CT_BUILD_DIR}/build-strip"
            cd "${CT_BUILD_DIR}/build-strip"
            ( cd "${CT_SRC_DIR}/ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}/sstrip"; tar cf - . ) |tar xf -

            CT_DoLog EXTRA "Building sstrip"
            CT_DoExecLog ALL make CC="${CT_HOST}-gcc" sstrip
            
            CT_DoLog EXTRA "Installing sstrip"
            CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

            CT_EndStep
        }
    ;;

    buildroot)
        do_tools_sstrip_get() {
            # We have to retrieve sstrip.c from a viewVC web interface. This
            # is not handled by the common CT_GetFile, thus we must take all
            # steps taken by CT_GetFile ourselves:

            CT_GetLocal sstrip .c && return 0 || true
            CT_TestAndAbort "File '${file}' not present locally, and downloads are not allowed" "${CT_FORBID_DOWNLOAD}" = "y"
            CT_DoLog EXTRA "Retrieving 'sstrip'"
            CT_DoGetFile "http://sources.busybox.net/index.py/trunk/buildroot/toolchain/sstrip/sstrip.c?view=co"
            mv "sstrip.c?view=co" "${CT_TARBALLS_DIR}/sstrip.c"
            CT_SaveLocal "${CT_TARBALLS_DIR}/sstrip.c"
        }
        do_tools_sstrip_extract() {
            # We'll let buildroot guys take care of sstrip maintenance and patching.
            mkdir -p "${CT_SRC_DIR}/sstrip"
            CT_DoExecLog ALL cp -v "${CT_TARBALLS_DIR}/sstrip.c" "${CT_SRC_DIR}/sstrip"
        }
        do_tools_sstrip_build() {
            CT_DoStep INFO "Installing sstrip"
            mkdir -p "${CT_BUILD_DIR}/build-sstrip"
            cd "${CT_BUILD_DIR}/build-sstrip"

            CT_DoLog EXTRA "Building sstrip"
            CT_DoExecLog ALL "${CT_HOST}-gcc" -Wall -o sstrip "${CT_SRC_DIR}/sstrip/sstrip.c"

            CT_DoLog EXTRA "Installing sstrip"
            CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

            CT_EndStep
        }
    ;;

    *)  do_tools_sstrip_get() {
            :
        }
        do_tools_sstrip_extract() {
            :
        }
        do_tools_sstrip_build() {
            :
        }
    ;;
esac
