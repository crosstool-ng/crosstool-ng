# This file contains crosstool-NG internal steps

# This step is called once all components were built, to remove
# un-wanted files, to add tuple aliases, and to add the final
# crosstool-NG-provided files.
do_finish() {
    local _t

    CT_DoStep INFO "Cleaning-up the toolchain's directory"

    CT_DoLog EXTRA "Removing access to the build system tools"
    find "${CT_PREFIX_DIR}/bin" -name "${CT_BUILD}-"'*' -exec rm -fv {} \; |CT_DoLog DEBUG
    find "${CT_PREFIX_DIR}/bin" -name "${CT_HOST}-"'*' -exec rm -fv {} \; |CT_DoLog DEBUG
    CT_DoExecLog DEBUG rm -fv "${CT_PREFIX_DIR}/bin/makeinfo"

    if [ "${CT_BARE_METAL}" != "y" ]; then
        CT_DoLog EXTRA "Installing the populate helper"
        sed -r -e 's|@@CT_TARGET@@|'"${CT_TARGET}"'|g;' \
               -e 's|@@CT_install@@|'"${install}"'|g;'  \
               -e 's|@@CT_bash@@|'"${bash}"'|g;'        \
               -e 's|@@CT_grep@@|'"${grep}"'|g;'        \
               -e 's|@@CT_make@@|'"${make}"'|g;'        \
               -e 's|@@CT_sed@@|'"${sed}"'|g;'          \
               "${CT_LIB_DIR}/scripts/populate.in"      \
               >"${CT_PREFIX_DIR}/bin/${CT_TARGET}-populate"
        CT_DoExecLog ALL chmod 755 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-populate"
    fi

    # Create the aliases to the target tools
    CT_DoLog EXTRA "Creating toolchain aliases"
    CT_Pushd "${CT_PREFIX_DIR}/bin"
    for t in "${CT_TARGET}-"*; do
        if [ -n "${CT_TARGET_ALIAS}" ]; then
            _t=$(echo "$t" |sed -r -e 's/^'"${CT_TARGET}"'-/'"${CT_TARGET_ALIAS}"'-/;')
            CT_DoExecLog ALL ln -sv "${t}" "${_t}"
        fi
        if [ -n "${CT_TARGET_ALIAS_SED_EXPR}" ]; then
            _t=$(echo "$t" |sed -r -e "${CT_TARGET_ALIAS_SED_EXPR}")
            CT_DoExecLog ALL ln -sv "${t}" "${_t}"
        fi
    done
    CT_Popd

    # If using the companion libraries, we need a wrapper
    # that will set LD_LIBRARY_PATH approriately
    if [    "${CT_GMP_MPFR}" = "y"      \
         -o "${CT_PPL_CLOOG_MPC}" = "y" ]; then
        CT_DoLog EXTRA "Installing toolchain wrappers"
        CT_Pushd "${CT_PREFIX_DIR}/bin"
        sed -r -e 's|@@CT_bash@@|'"${bash}"'|g;'    \
            "${CT_LIB_DIR}/scripts/wrapper.in"      \
            >".${CT_TARGET}-wrapper"
        CT_DoExecLog ALL chmod 755 ".${CT_TARGET}-wrapper"
        for t in "${CT_TARGET}-"*; do
            CT_DoExecLog ALL mv "${t}" ".${t}"
            CT_DoExecLog ALL ln ".${CT_TARGET}-wrapper" "${t}"
        done
        CT_Popd
    fi

    # Remove the generated documentation files
    if [ "${CT_REMOVE_DOCS}" = "y" ]; then
        CT_DoLog EXTRA "Removing installed documentation"
        CT_DoForceRmdir "${CT_PREFIX_DIR}/"{,usr/}{man,info}
        CT_DoForceRmdir "${CT_SYSROOT_DIR}/"{,usr/}{man,info}
        CT_DoForceRmdir "${CT_DEBUGROOT_DIR}/"{,usr/}{man,info}
    fi

    CT_EndStep
}
