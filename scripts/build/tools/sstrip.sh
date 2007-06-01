# This will build and install sstrip to run on host and sstrip target files

is_enabled="${CT_SSTRIP}"

case "${CT_SSTRIP_FROM}" in
    ELFkickers)
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
            make CC="${CT_CC_NATIVE}" sstrip 2>&1 |CT_DoLog ALL
            
            CT_DoLog EXTRA "Installing sstrip"
            install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip" 2>&1 |CT_DoLog ALL

            CT_EndStep
        }
    ;;

    buildroot)
        sstrip_url='http://buildroot.uclibc.org/cgi-bin/viewcvs.cgi/trunk/buildroot/toolchain/sstrip/sstrip.c'
        do_tools_sstrip_get() {
            # With this one, we must handle the download by ourselves,
            # we can't leave the job to the classic CT_GetFile.
            if [ -f "${CT_SRC_DIR}/sstrip/sstrip.c" ]; then
                return 0
            fi
            CT_Pushd "${CT_SRC_DIR}"
            CT_DoLog EXTRA "Retrieving sstrip (buildroot)"
            mkdir -p sstrip
            cd sstrip
            http_data=`lynx -dump "${sstrip_url}"`
            link=`echo -en "${http_data}"                           \
                  |egrep '\[[[:digit:]]+\]download'                 \
                  |sed -r -e 's/.*\[([[:digit:]]+)\]download.*/\1/;'`
            rev_url=`echo -en "${http_data}"                        \
                     |egrep '^ *8\.'                                \
                     |sed -r -e 's/^ *'${link}'\. +(.+)$/\1/;'`
            CT_DoGetFile "${rev_url}" 2>&1 |CT_DoLog ALL
            mv sstrip.c?* sstrip.c
            CT_Popd
        }
        do_tools_sstrip_extract() {
            # We'll let buildroot guys take care of sstrip maintenance and patching.
            :
        }
        do_tools_sstrip_build() {
            CT_DoStep INFO "Installing sstrip"
            mkdir -p "${CT_BUILD_DIR}/build-sstrip"
            cd "${CT_BUILD_DIR}/build-sstrip"

            CT_DoLog EXTRA "Building sstrip"
            ${CT_CC_NATIVE} -Wall -o sstrip "${CT_SRC_DIR}/sstrip/sstrip.c" 2>&1 |CT_DoLog ALL

            CT_DoLog EXTRA "Installing sstrip"
            install -m 755 sstrip "${CT_PREFIX_DIR}/bin/${CT_TARGET}-sstrip" 2>&1 |CT_DoLog ALL

            CT_EndStep
        }
    ;;
esac
