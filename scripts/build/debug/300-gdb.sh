# Build script for the gdb debug facility

do_debug_gdb_get() {
    CT_Fetch GDB
}

do_debug_gdb_extract() {
    CT_ExtractPatch GDB
}

do_debug_gdb_build() {
    local -a extra_config

    gdb_src_dir="${CT_SRC_DIR}/gdb"

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
        local gcc_version p _p

        CT_DoStep INFO "Installing cross-gdb"
        CT_DoLog EXTRA "Configuring cross-gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-cross"
        cd "${CT_BUILD_DIR}/build-gdb-cross"

        cross_extra_config=("${extra_config[@]}")

        # For gdb-cross this combination of flags forces
        # gdb configure to fall back to default '-lexpat' flag
        # which is acceptable.
        #
        # NOTE: DO NOT USE --with-libexpat-prefix (until GDB configure is smarter)!!!
        # It conflicts with a static build: GDB's configure script will find the shared
        # version of expat and will attempt to link that, despite the -static flag.
        # The link will fail, and configure will abort with "expat missing or unusable"
        # message.
        cross_extra_config+=("--with-expat")
        cross_extra_config+=("--without-libexpat-prefix")

        case "${CT_THREADS}" in
            none)   cross_extra_config+=("--disable-threads");;
            *)      cross_extra_config+=("--enable-threads");;
        esac
        if [ "${CT_GDB_CROSS_PYTHON}" = "y" ]; then
            if [ -z "${CT_GDB_CROSS_PYTHON_BINARY}" ]; then
                for p in python python3 python2; do
                    _p=$( which "${p}" || true )
                    if [ -n "${_p}" ]; then
                       cross_extra_config+=( "--with-python=${_p}" )
                       break
                    fi
                done
                if [ -z "${_p}" ]; then
                    CT_Abort "Python support requested in cross-gdb, but Python not found. Set CT_GDB_CROSS_PYTHON_BINARY in your config."
                fi
            else
                cross_extra_config+=( "--with-python=${CT_GDB_CROSS_PYTHON_BINARY}" )
            fi
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

        CPP_for_gdb="${CT_HOST}-cpp ${CT_CFLAGS_FOR_HOST}"
        CC_for_gdb="${CT_HOST}-gcc ${CT_CFLAGS_FOR_HOST} ${CT_LDFLAGS_FOR_HOST}"
        CXX_for_gdb="${CT_HOST}-g++ ${CT_CFLAGS_FOR_HOST} ${CT_LDFLAGS_FOR_HOST}"
        LD_for_gdb="${CT_HOST}-ld ${CT_LDFLAGS_FOR_HOST}"
        if [ "${CT_GDB_CROSS_STATIC}" = "y" ]; then
            CC_for_gdb+=" -static"
            CXX_for_gdb+=" -static"
            LD_for_gdb+=" -static"
        fi
        case "${CT_HOST}" in
            *darwin*)
                # FIXME: Really, we should be testing for host compiler being clang.
                CC_for_gdb+=" -Qunused-arguments"
                CXX_for_gdb+=" -Qunused-arguments"
                # clang detects the line from gettext's _ macro as format string
                # not being a string literal and produces a lot of warnings - which
                # ct-ng's logger faithfully relays to user if this happens in the
                # error() function. Suppress them.
                cross_extra_config+=( "--enable-build-warnings=,-Wno-format-nonliteral,-Wno-format-security" )
                ;;
        esac

        # Fix up whitespace. Some older GDB releases (e.g. 6.8a) get confused if there
        # are multiple consecutive spaces: sub-configure scripts replace them with a
        # single space and then complain that $CC value changed from that in
        # the master directory.
        CPP_for_gdb=`echo $CPP_for_gdb`
        CC_for_gdb=`echo $CC_for_gdb`
        CXX_for_gdb=`echo $CXX_for_gdb`
        LD_for_gdb=`echo $LD_for_gdb`

        # Disable binutils options when building from the binutils-gdb repo.
        cross_extra_config+=("--disable-binutils")
        cross_extra_config+=("--disable-ld")
        cross_extra_config+=("--disable-gas")

        CT_DoLog DEBUG "Extra config passed: '${cross_extra_config[*]}'"

        CT_DoExecLog CFG                                \
        CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
        CFLAGS_FOR_BUILD="${CT_CFLAGS_FOR_BUILD}"       \
        LDFLAGS_FOR_BUILD="${CT_LDFLAGS_FOR_BUILD}"     \
        CPP="${CPP_for_gdb}"                            \
        CC="${CC_for_gdb}"                              \
        CXX="${CXX_for_gdb}"                            \
        LD="${LD_for_gdb}"                              \
        ${CONFIG_SHELL}                                 \
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
        CT_DoExecLog ALL make ${JOBSFLAGS}

        CT_DoLog EXTRA "Installing cross-gdb"
        CT_DoExecLog ALL make install

        if [ "${CT_BUILD_MANUALS}" = "y" ]; then
            CT_DoLog EXTRA "Building and installing the cross-GDB manuals"
            CT_DoExecLog ALL make ${JOBSFLAGS} pdf html
            CT_DoExecLog ALL make install-{pdf,html}-gdb
        fi

        if [ "${CT_GDB_INSTALL_GDBINIT}" = "y" ]; then
            CT_DoLog EXTRA "Installing '.gdbinit' template"
            # See in scripts/build/internals.sh for why we do this
            # TBD GCC 3.x and older not supported
            if [ -f "${CT_SRC_DIR}/gcc/gcc/BASE-VER" ]; then
                gcc_version=$( cat "${CT_SRC_DIR}/gcc/gcc/BASE-VER" )
            else
                gcc_version=$(sed -r -e '/version_string/!d; s/^.+= "([^"]+)".*$/\1/;'   \
                                   "${CT_SRC_DIR}/gcc/gcc/version.c"   \
                             )
            fi
            sed -r                                               \
                   -e "s:@@PREFIX@@:${CT_PREFIX_DIR}:;"             \
                   -e "s:@@VERSION@@:${gcc_version}:;"              \
                   "${CT_LIB_DIR}/scripts/build/debug/gdbinit.in"   \
                   >"${CT_PREFIX_DIR}/share/gdb/gdbinit"
        fi # Install gdbinit sample

        CT_EndStep
    fi

    # TBD combine GDB native and gdbserver backends, build either or both in a single pass.
    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        local -a native_extra_config

        CT_DoStep INFO "Installing native gdb"

        native_extra_config=("${extra_config[@]}")

        # We may not have C++ language configured for target
        if [ "${GDB_TARGET_DISABLE_CXX_BUILD}" = "y" ]; then
            native_extra_config+=("--disable-build-with-cxx")
        fi

        # GDB on Mingw depends on PDcurses, not ncurses
        if [ "${CT_MINGW32}" != "y" ]; then
            native_extra_config+=("--with-curses")
        fi

        # Target libexpat resides in sysroot and does not have
        # any dependencies, so just passing '-lexpat' to gcc is enough.
        #
        # By default gdb configure looks for expat in '$prefix/lib'
        # directory. In our case '$prefix/lib' resolves to '/usr/lib'
        # where libexpat for build platform lives, which is
        # unacceptable for cross-compiling.
        #
        # To prevent this '--without-libexpat-prefix' flag must be passed.
        # Thus configure falls back to '-lexpat', which is exactly what we want.
        #
        # NOTE: DO NOT USE --with-libexpat-prefix (until GDB configure is smarter)!!!
        # It conflicts with a static build: GDB's configure script will find the shared
        # version of expat and will attempt to link that, despite the -static flag.
        # The link will fail, and configure will abort with "expat missing or unusable"
        # message.
        native_extra_config+=("--with-expat")
        native_extra_config+=("--without-libexpat-prefix")

        CT_DoLog EXTRA "Configuring native gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-native"
        cd "${CT_BUILD_DIR}/build-gdb-native"

        case "${CT_THREADS}" in
            none)   native_extra_config+=("--disable-threads");;
            *)      native_extra_config+=("--enable-threads");;
        esac

        [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] &&    \
        native_extra_config+=("--disable-nls")

        CPP_for_gdb="${CT_TARGET}-cpp"
        CC_for_gdb="${CT_TARGET}-${CT_CC}"
        CXX_for_gdb="${CT_TARGET}-g++"
        LD_for_gdb="${CT_TARGET}-ld"
        if [ "${CT_GDB_NATIVE_STATIC}" = "y" ]; then
            CC_for_gdb+=" -static"
            CXX_for_gdb+=" -static"
            LD_for_gdb+=" -static"
        fi

        export ac_cv_func_strncmp_works=yes

        # Disable binutils options when building from the binutils-gdb repo.
        native_extra_config+=("--disable-binutils")
        native_extra_config+=("--disable-ld")
        native_extra_config+=("--disable-gas")

        CT_DoLog DEBUG "Extra config passed: '${native_extra_config[*]}'"

        CT_DoExecLog CFG                                \
        CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
        CFLAGS_FOR_BUILD="${CT_CFLAGS_FOR_BUILD}"       \
        LDFLAGS_FOR_BUILD="${CT_LDFLAGS_FOR_BUILD}"     \
        CPP="${CPP_for_gdb}"                            \
        CC="${CC_for_gdb}"                              \
        CXX="${CXX_for_gdb}"                            \
        LD="${LD_for_gdb}"                              \
        ${CONFIG_SHELL}                                 \
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
        CT_DoExecLog ALL make ${JOBSFLAGS}

        CT_DoLog EXTRA "Installing native gdb"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

        # Building a native gdb also builds a gdbserver
        find "${CT_DEBUGROOT_DIR}" -type f -name gdbserver -exec rm -fv {} \; 2>&1 |CT_DoLog ALL

        unset ac_cv_func_strncmp_works

        CT_EndStep # native gdb build
    fi

    if [ "${CT_GDB_GDBSERVER}" = "y" ]; then
        local -a gdbserver_extra_config
        local gdbserver_LDFLAGS

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

        if [ "${CT_GDB_GDBSERVER_STATIC_LIBSTDCXX}" = "y" ]; then
            gdbserver_LDFLAGS+=" -static-libstdc++"
        fi

        gdbserver_extra_config=("${extra_config[@]}")

        # We may not have C++ language configured for target
        if [ "${GDB_TARGET_DISABLE_CXX_BUILD}" = "y" ]; then
            gdbserver_extra_config+=("--disable-build-with-cxx")
        fi

        if [ "${CT_GDB_GDBSERVER_HAS_IPA_LIB}" = "y" ]; then
            if [ "${CT_GDB_GDBSERVER_BUILD_IPA_LIB}" = "y" ]; then
                gdbserver_extra_config+=( --enable-inprocess-agent )
            else
                gdbserver_extra_config+=( --disable-inprocess-agent )
            fi
        fi

        # Disable binutils options when building from the binutils-gdb repo.
        gdbserver_extra_config+=("--disable-binutils")
        gdbserver_extra_config+=("--disable-ld")
        gdbserver_extra_config+=("--disable-gas")

        CT_DoExecLog CFG                                \
        CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
        CFLAGS_FOR_BUILD="${CT_CFLAGS_FOR_BUILD}"       \
        LDFLAGS_FOR_BUILD="${CT_LDFLAGS_FOR_BUILD}"     \
        CC="${CT_TARGET}-${CT_CC}"                      \
        CPP="${CT_TARGET}-cpp"                          \
        LD="${CT_TARGET}-ld"                            \
        LDFLAGS="${gdbserver_LDFLAGS}"                  \
        ${CONFIG_SHELL}                                 \
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
        CT_DoExecLog ALL make ${JOBSFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing gdbserver"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

        CT_EndStep
    fi
}
