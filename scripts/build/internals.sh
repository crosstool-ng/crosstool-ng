# This file contains crosstool-NG internal steps

# This step is called once all components were built, to remove
# un-wanted files, to add tuple aliases, and to add the final
# crosstool-NG-provided files.
do_finish() {
    local _t
    local _type
    local strip_args
    local gcc_version

    CT_DoStep INFO "Cleaning-up the toolchain's directory"

    if [ "${CT_STRIP_ALL_TOOLCHAIN_EXECUTABLES}" = "y" ]; then
        case "$CT_HOST" in
            *darwin*)
                strip_args=""
                ;;
            *)
                strip_args="--strip-all -v"
                ;;
        esac
        CT_DoLog INFO "Stripping all toolchain executables"
        CT_Pushd "${CT_PREFIX_DIR}"
        gcc_version=$( cat "${CT_SRC_DIR}/gcc-${CT_GCC_VERSION}/gcc/BASE-VER" )
        for _t in "bin/${CT_TARGET}-"*                                      \
                  "${CT_TARGET}/bin/"*                                      \
                  "libexec/gcc/${CT_TARGET}/${gcc_version}/"*               \
                  "libexec/gcc/${CT_TARGET}/${gcc_version}/install-tools/"* \
        ; do
            _type="$( file "${_t}" |cut -d ' ' -f 2- )"
            case "${_type}" in
                *script*executable*)
                    ;;
                *executable*)
                    CT_DoExecLog ALL ${CT_HOST}-strip ${strip_args} "${_t}"
                    ;;
            esac
        done
        CT_Popd
    fi

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

    if [ "${CT_LIBC_XLDD}" = "y" ]; then
        CT_DoLog EXTRA "Installing a cross-ldd helper"
        sed -r -e 's|@@CT_VERSION@@|'"${CT_VERSION}"'|g;'   \
               -e 's|@@CT_TARGET@@|'"${CT_TARGET}"'|g;'     \
               -e 's|@@CT_BITS@@|'"${CT_ARCH_BITNESS}"'|g;' \
               -e 's|@@CT_install@@|'"${install}"'|g;'      \
               -e 's|@@CT_bash@@|'"${bash}"'|g;'            \
               -e 's|@@CT_grep@@|'"${grep}"'|g;'            \
               -e 's|@@CT_make@@|'"${make}"'|g;'            \
               -e 's|@@CT_sed@@|'"${sed}"'|g;'              \
               "${CT_LIB_DIR}/scripts/xldd.in"              \
               >"${CT_PREFIX_DIR}/bin/${CT_TARGET}-ldd"
        CT_DoExecLog ALL chmod 755 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-ldd"
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
            if [ "${_t}" = "${t}" ]; then
                CT_DoLog WARN "The sed expression '${CT_TARGET_ALIAS_SED_EXPR}' has no effect on '${t}'"
            else
                CT_DoExecLog ALL ln -sv "${t}" "${_t}"
            fi
        fi
    done
    CT_Popd

    CT_DoLog EXTRA "Removing access to the build system tools"
    CT_DoExecLog DEBUG rm -rf "${CT_PREFIX_DIR}/buildtools"

    # Remove the generated documentation files
    if [ "${CT_REMOVE_DOCS}" = "y" ]; then
        CT_DoLog EXTRA "Removing installed documentation"
        CT_DoForceRmdir "${CT_PREFIX_DIR}/"{,usr/}{,share/}{man,info}
        CT_DoForceRmdir "${CT_SYSROOT_DIR}/"{,usr/}{,share/}{man,info}
        CT_DoForceRmdir "${CT_DEBUGROOT_DIR}/"{,usr/}{,share/}{man,info}
    fi

    # Remove the lib* symlinks, now:
    # The symlinks are needed only during the build process.
    # The final gcc will still search those dirs, but will also search
    # the standard lib/ dirs, so we can get rid of the symlinks
    for d in                            \
        "${CT_PREFIX_DIR}"              \
        "${CT_PREFIX_DIR}/${CT_TARGET}" \
    ; do
        CT_DoExecLog ALL rm -f "${d}/lib32"
        CT_DoExecLog ALL rm -f "${d}/lib64"
    done

    # Also remove the lib/ symlink out-side of sysroot
    if [ "${CT_USE_SYSROOT}" = "y" ]; then
        CT_DoExecLog ALL rm -f "${CT_PREFIX_DIR}/${CT_TARGET}/lib"
    fi

    CT_EndStep
}
