# Build script for the gdb debug facility

if [ "${CT_GDB_CROSS}" = y -o "${CT_GDB_GDBSERVER}" = "y" -o "${CT_GDB_NATIVE}" = "y" ]; then

do_debug_gdb_get() {
    local linaro_version=""
    local linaro_series=""

    if [ "${CT_GDB_CUSTOM}" = "y" ]; then
        CT_GetCustom "gdb" "${CT_GDB_VERSION}" "${CT_GDB_CUSTOM_LOCATION}"
    else
        # Account for the Linaro versioning
        linaro_version="$( echo "${CT_GDB_VERSION}"      \
                           |${sed} -r -e 's/^linaro-//;'   \
                         )"
        linaro_series="$( echo "${linaro_version}"      \
                          |${sed} -r -e 's/-.*//;'         \
                        )"

        if [ x"${linaro_version}" = x"${CT_GDB_VERSION}" ]; then
            CT_GetFile "gdb-${CT_GDB_VERSION}"                             \
                       http://mirrors.kernel.org/sourceware/gdb            \
                       {http,ftp,https}://ftp.gnu.org/pub/gnu/gdb          \
                       ftp://{sourceware.org,gcc.gnu.org}/pub/gdb/releases
        else
            YYMM=`echo ${CT_GDB_VERSION} |cut -d- -f3 |${sed} -e 's,^..,,'`
            CT_GetFile "gdb-${CT_GDB_VERSION}"                                                        \
                       "http://launchpad.net/gdb-linaro/${linaro_series}/${linaro_version}/+download" \
                       https://releases.linaro.org/${YYMM}/components/toolchain/gdb-linaro            \
                       http://cbuild.validation.linaro.org/snapshots
        fi
    fi
}

do_debug_gdb_extract() {
    # If using custom directory location, nothing to do
    if [    "${CT_GDB_CUSTOM}" = "y" \
         -a -d "${CT_SRC_DIR}/gdb-${CT_GDB_VERSION}" ]; then
        return 0
    fi

    CT_Extract "gdb-${CT_GDB_VERSION}"
    CT_Patch "gdb" "${CT_GDB_VERSION}"

    if [ -n "${CT_ARCH_XTENSA_CUSTOM_NAME}" ]; then
        CT_ConfigureXtensa "gdb" "${CT_GDB_VERSION}"
    fi
}

do_debug_gdb_build() {
    local -a extra_config

    gdb_src_dir="${CT_SRC_DIR}/gdb-${CT_GDB_VERSION}"

    # Version 6.3 and below behave badly with gdbmi
    case "${CT_GDB_VERSION}" in
        6.2*|6.3)   extra_config+=("--disable-gdbmi");;
    esac

    if [ "${CT_GDB_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    if [ "${CT_GDB_CROSS}" = "y" ]; then
        local -a cross_extra_config
        local gcc_version

        CT_DoStep INFO "Installing cross-gdb"
        CT_DoLog EXTRA "Configuring cross-gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-cross"
        cd "${CT_BUILD_DIR}/build-gdb-cross"

        cross_extra_config=("${extra_config[@]}")
        cross_extra_config+=("--with-expat")
        cross_extra_config+=("--with-libexpat-prefix=${CT_HOST_COMPLIBS_DIR}")
        case "${CT_THREADS}" in
            none)   cross_extra_config+=("--disable-threads");;
            *)      cross_extra_config+=("--enable-threads");;
        esac
        if [ "${CT_GDB_CROSS_PYTHON}" = "y" ]; then
            cross_extra_config+=( "--with-python=yes" )
        else
            cross_extra_config+=( "--with-python=no" )
        fi
        if [ "${CT_GDB_CROSS_SIM}" = "y" ]; then
            cross_extra_config+=( "--enable-sim" )
        else
            cross_extra_config+=( "--disable-sim" )
        fi
        if [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ]; then
            cross_extra_config+=("--disable-nls")
        fi

        CC_for_gdb=
        LD_for_gdb=
        if [ "${CT_GDB_CROSS_STATIC}" = "y" ]; then
            CC_for_gdb="${CT_HOST}-gcc -static"
            LD_for_gdb="${CT_HOST}-ld -static"
        fi

        CT_DoLog DEBUG "Extra config passed: '${cross_extra_config[*]}'"

        CT_DoExecLog CFG                                \
        CC="${CC_for_gdb}"                              \
        LD="${LD_for_gdb}"                              \
        "${gdb_src_dir}/configure"                      \
            --build=${CT_BUILD}                         \
            --host=${CT_HOST}                           \
            --target=${CT_TARGET}                       \
            --prefix="${CT_PREFIX_DIR}"                 \
            --with-build-sysroot="${CT_SYSROOT_DIR}"    \
            --with-sysroot="${CT_SYSROOT_DIR}"          \
            --disable-werror                            \
            "${cross_extra_config[@]}"                  \
            "${CT_GDB_CROSS_EXTRA_CONFIG_ARRAY[@]}"

        CT_DoLog EXTRA "Building cross-gdb"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS}

        CT_DoLog EXTRA "Installing cross-gdb"
        CT_DoExecLog ALL ${make} install

        if [ "${CT_BUILD_MANUALS}" = "y" ]; then
            CT_DoLog EXTRA "Building and installing the cross-GDB manuals"
            CT_DoExecLog ALL ${make} ${JOBSFLAGS} pdf html
            CT_DoExecLog ALL ${make} install-{pdf,html}-gdb
        fi

        if [ "${CT_GDB_INSTALL_GDBINIT}" = "y" ]; then
            CT_DoLog EXTRA "Installing '.gdbinit' template"
            # See in scripts/build/internals.sh for why we do this
            if [ -f "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/gcc/BASE-VER" ]; then
                gcc_version=$( cat "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/gcc/BASE-VER" )
            else
                gcc_version=$(${sed} -r -e '/version_string/!d; s/^.+= "([^"]+)".*$/\1/;'   \
                                   "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/gcc/version.c"   \
                             )
            fi
            ${sed} -r                                               \
                   -e "s:@@PREFIX@@:${CT_PREFIX_DIR}:;"             \
                   -e "s:@@VERSION@@:${gcc_version}:;"              \
                   "${CT_LIB_DIR}/scripts/build/debug/gdbinit.in"   \
                   >"${CT_PREFIX_DIR}/share/gdb/gdbinit"
        fi # Install gdbinit sample

        CT_EndStep
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        local -a native_extra_config
        local -a gdb_native_CFLAGS

        CT_DoStep INFO "Installing native gdb"

        native_extra_config=("${extra_config[@]}")

        # GDB on Mingw depends on PDcurses, not ncurses
        if [ "${CT_MINGW32}" != "y" ]; then
            native_extra_config+=("--with-curses")
        fi

        native_extra_config+=("--with-expat")

        CT_DoLog EXTRA "Configuring native gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-native"
        cd "${CT_BUILD_DIR}/build-gdb-native"

        case "${CT_THREADS}" in
            none)   native_extra_config+=("--disable-threads");;
            *)      native_extra_config+=("--enable-threads");;
        esac

        [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] &&    \
        native_extra_config+=("--disable-nls")

        if [ "${CT_GDB_NATIVE_STATIC}" = "y" ]; then
            CC_for_gdb="${CT_TARGET}-gcc -static"
            LD_for_gdb="${CT_TARGET}-ld -static"
        else
            CC_for_gdb="${CT_TARGET}-gcc"
            LD_for_gdb="${CT_TARGET}-ld"
        fi

        export ac_cv_func_strncmp_works=yes

        CT_DoLog DEBUG "Extra config passed: '${native_extra_config[*]}'"

        CT_DoExecLog CFG                                \
        CC="${CC_for_gdb}"                              \
        LD="${LD_for_gdb}"                              \
        CFLAGS="${gdb_native_CFLAGS[*]}"                \
        "${gdb_src_dir}/configure"                      \
            --build=${CT_BUILD}                         \
            --host=${CT_TARGET}                         \
            --target=${CT_TARGET}                       \
            --prefix=/usr                               \
            --with-build-sysroot="${CT_SYSROOT_DIR}"    \
            --without-uiout                             \
            --disable-tui                               \
            --disable-gdbtk                             \
            --without-x                                 \
            --disable-sim                               \
            --disable-werror                            \
            --without-included-gettext                  \
            --without-develop                           \
            "${native_extra_config[@]}"

        CT_DoLog EXTRA "Building native gdb"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing native gdb"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_DEBUGROOT_DIR}" install

        # Building a native gdb also builds a gdbserver
        find "${CT_DEBUGROOT_DIR}" -type f -name gdbserver -exec rm -fv {} \; 2>&1 |CT_DoLog ALL

        unset ac_cv_func_strncmp_works

        CT_EndStep # native gdb build
    fi

    if [ "${CT_GDB_GDBSERVER}" = "y" ]; then
        local -a gdbserver_extra_config

        CT_DoStep INFO "Installing gdbserver"
        CT_DoLog EXTRA "Configuring gdbserver"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-gdbserver"
        cd "${CT_BUILD_DIR}/build-gdb-gdbserver"

        # Workaround for bad versions, where the configure
        # script for gdbserver is not executable...
        # Bah, GNU folks strike again... :-(
        chmod +x "${gdb_src_dir}/gdb/gdbserver/configure"

        gdbserver_LDFLAGS=
        if [ "${CT_GDB_GDBSERVER_STATIC}" = "y" ]; then
            gdbserver_LDFLAGS=-static
        fi

        gdbserver_extra_config=("${extra_config[@]}")

        if [ "${CT_GDB_GDBSERVER_HAS_IPA_LIB}" = "y" ]; then
            if [ "${CT_GDB_GDBSERVER_BUILD_IPA_LIB}" = "y" ]; then
                gdbserver_extra_config+=( --enable-inprocess-agent )
            else
                gdbserver_extra_config+=( --disable-inprocess-agent )
            fi
        fi

        CT_DoExecLog CFG                                \
        CC="${CT_TARGET}-gcc"                           \
        CPP="${CT_TARGET}-cpp"                          \
        LD="${CT_TARGET}-ld"                            \
        LDFLAGS="${gdbserver_LDFLAGS}"                  \
        "${gdb_src_dir}/gdb/gdbserver/configure"        \
            --build=${CT_BUILD}                         \
            --host=${CT_TARGET}                         \
            --target=${CT_TARGET}                       \
            --prefix=/usr                               \
            --sysconfdir=/etc                           \
            --localstatedir=/var                        \
            --includedir="${CT_HEADERS_DIR}"            \
            --with-build-sysroot="${CT_SYSROOT_DIR}"    \
            --program-prefix=                           \
            --without-uiout                             \
            --disable-tui                               \
            --disable-gdbtk                             \
            --without-x                                 \
            --without-included-gettext                  \
            --without-develop                           \
            --disable-werror                            \
            "${gdbserver_extra_config[@]}"

        CT_DoLog EXTRA "Building gdbserver"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing gdbserver"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_DEBUGROOT_DIR}" install

        CT_EndStep
    fi
}

fi
