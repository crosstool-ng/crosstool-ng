# eglibc build functions (initially by Thomas JOURDAN).

# Add the definitions common to glibc and eglibc
#   do_libc_extract
#   do_libc_start_files
#   do_libc
#   do_libc_finish
#   do_libc_add_ons_list
#   do_libc_min_kernel_config
. "${CT_LIB_DIR}/scripts/build/libc/glibc-eglibc.sh-common"

# Download glibc
# eglibc is only available through subversion, there are no
# snapshots available.
do_libc_get() {
    local addon
    local svn_base

    if [ "${CT_EGLIBC_HTTP}" = "y" ]; then
        svn_base="http://www.eglibc.org/svn"
    else
        svn_base="svn://svn.eglibc.org"
    fi

    case "${CT_LIBC_VERSION}" in
        trunk)  svn_base+="/trunk";;
        *)      svn_base+="/branches/eglibc-${CT_LIBC_VERSION}";;
    esac

    CT_GetSVN "eglibc-${CT_LIBC_VERSION}"   \
              "${svn_base}/libc"            \
              "${CT_EGLIBC_REVISION:-HEAD}"

    for addon in $(do_libc_add_ons_list " "); do
        # Never ever try to download these add-ons,
        # they've always been internal
        case "${addon}" in
            nptl)   continue;;
        esac

        if ! CT_GetSVN "eglibc-${addon}-${CT_LIBC_VERSION}" \
                       "${svn_base}/${addon}"               \
                       "${CT_EGLIBC_REVISION:-HEAD}"
        then
            # Some add-ons are bundled with the main sources
            # so failure to download them is expected
            CT_DoLog DEBUG "Addon '${addon}' could not be downloaded."
            CT_DoLog DEBUG "We'll see later if we can find it in the source tree"
        fi
    done
}

# Copy user provided eglibc configuration file if provided
do_libc_check_config() {
    if [ "${CT_EGLIBC_CUSTOM_CONFIG}" != "y" ]; then
        return 0
    fi

    CT_DoStep INFO "Checking C library configuration"

    CT_TestOrAbort "You did not provide an eglibc config file!" \
        -n "${CT_EGLIBC_OPTION_GROUPS_FILE}" -a \
        -f "${CT_EGLIBC_OPTION_GROUPS_FILE}"

    CT_DoExecLog ALL cp "${CT_EGLIBC_OPTION_GROUPS_FILE}" "${CT_CONFIG_DIR}/eglibc.config"

    # NSS configuration
    if grep -E '^OPTION_EGLIBC_NSSWITCH[[:space:]]*=[[:space:]]*n' "${CT_EGLIBC_OPTION_GROUPS_FILE}" >/dev/null 2>&1; then
        CT_DoLog DEBUG "Using fixed-configuration nsswitch facility"

        if [ "${CT_EGLIBC_BUNDLED_NSS_CONFIG}" = "y" ]; then
            nss_config="${CT_SRC_DIR}/eglibc-${CT_LIBC_VERSION}/nss/fixed-nsswitch.conf"
        else
            nss_config="${CT_EGLIBC_NSS_CONFIG_FILE}"
        fi
        CT_TestOrAbort "NSS config file not found!" -n "${nss_config}" -a -f "${nss_config}"

        CT_DoExecLog ALL cp "${nss_config}" "${CT_CONFIG_DIR}/nsswitch.config"
        echo "OPTION_EGLIBC_NSSWITCH_FIXED_CONFIG = ${CT_CONFIG_DIR}/nsswitch.config" \
            >> "${CT_CONFIG_DIR}/eglibc.config"

        if [ "${CT_EGLIBC_BUNDLED_NSS_FUNCTIONS}" = "y" ]; then
            nss_functions="${CT_SRC_DIR}/eglibc-${CT_LIBC_VERSION}/nss/fixed-nsswitch.functions"
        else
            nss_functions="${CT_EGLIBC_NSS_FUNCTIONS_FILE}"
        fi
        CT_TestOrAbort "NSS functions file not found!" -n "${nss_functions}" -a -f "${nss_functions}"

        CT_DoExecLog ALL cp "${nss_functions}" "${CT_CONFIG_DIR}/nsswitch.functions"
        echo "OPTION_EGLIBC_NSSWITCH_FIXED_FUNCTIONS = ${CT_CONFIG_DIR}/nsswitch.functions" \
            >> "${CT_CONFIG_DIR}/eglibc.config"
    else
        CT_DoLog DEBUG "Using full-blown nsswitch facility"
    fi

    CT_EndStep
}
