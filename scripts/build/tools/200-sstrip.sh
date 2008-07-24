# This will build and install sstrip to run on host and sstrip target files

is_enabled="${CT_SSTRIP}"

case "${CT_SSTRIP_FROM}" in
    ELFkickers)
        do_print_filename() {
            echo "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"
        }
        do_tools_sstrip_get() {
            CT_GetFile "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"     \
                       http://www.muppetlabs.com/~breadbox/pub/software
        }
        do_tools_sstrip_extract() {
            CT_ExtractAndPatch "ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}"
        }
        do_tools_sstrip_build() {
            CT_DoStep INFO "Installing sstrip"
            mkdir -p "${CT_BUILD_DIR}/build-strip"
            cd "${CT_BUILD_DIR}/build-strip"
            ( cd "${CT_SRC_DIR}/ELFkickers-${CT_SSTRIP_ELFKICKERS_VERSION}/sstrip"; tar cf - . ) |tar xf -

            CT_DoLog EXTRA "Building sstrip"
            CT_DoExecLog ALL make CC="${CT_CC_NATIVE}" sstrip
            
            CT_DoLog EXTRA "Installing sstrip"
            CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

            CT_EndStep
        }
    ;;

    buildroot)
        do_print_filename() {
            echo "sstrip.c"
        }
        do_tools_sstrip_get() {
            # Note: the space between sstrip and .c is on purpose.
            CT_GetFile sstrip .c    \
                       "http://buildroot.uclibc.org/cgi-bin/viewcvs.cgi/*checkout*/trunk/buildroot/toolchain/sstrip/"
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
            CT_DoExecLog ALL ${CT_CC_NATIVE} -Wall -o sstrip "${CT_SRC_DIR}/sstrip/sstrip.c"

            CT_DoLog EXTRA "Installing sstrip"
            CT_DoExecLog ALL install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip"

            CT_EndStep
        }
    ;;

    *)  do_print_filename() {
            :
        }
        do_tools_sstrip_get() {
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
