# Build script for the gdb debug facility

do_debug_gdb_get()
{
    CT_Fetch GDB
}

do_debug_gdb_extract()
{
    CT_ExtractPatch GDB
}

do_debug_gdb_build()
{
    if [ "${CT_GDB_CROSS}" = "y" ]; then
        local gcc_version p _p
        local -a cross_extra_config

        CT_DoStep INFO "Installing cross-gdb"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-gdb-cross"

        cross_extra_config=( "${CT_GDB_CROSS_EXTRA_CONFIG_ARRAY[@]}" )
        if [ "${CT_GDB_CROSS_PYTHON}" = "y" ]; then
            if [ -z "${CT_GDB_CROSS_PYTHON_BINARY}" ]; then
                if [ "${CT_CANADIAN}" = "y" -o "${CT_CROSS_NATIVE}" = "y" ]; then
                    CT_Abort "For canadian build, Python wrapper runnable on the build machine must be provided. Set CT_GDB_CROSS_PYTHON_BINARY."
                elif [ "${CT_CONFIGURE_has_python}" = "y" ]; then
                    cross_extra_config+=("--with-python=${python}")
                else
                    CT_Abort "Python support requested in GDB, but Python not found. Set CT_GDB_CROSS_PYTHON_BINARY."
                fi
            else
                cross_extra_config+=("--with-python=${CT_GDB_CROSS_PYTHON_BINARY}")
            fi
        else
            cross_extra_config+=("--with-python=no")
        fi

        if [ "${CT_GDB_CROSS_SIM}" = "y" ]; then
            cross_extra_config+=("--enable-sim")
        else
            cross_extra_config+=("--disable-sim")
        fi

        if ${CT_HOST}-gcc --version 2>&1 | grep clang; then
            # clang detects the line from gettext's _ macro as format string
            # not being a string literal and produces a lot of warnings - which
            # ct-ng's logger faithfully relays to user if this happens in the
            # error() function. Suppress them.
            cross_extra_config+=("--enable-build-warnings=,-Wno-format-nonliteral,-Wno-format-security")
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
        extra_config+=("--with-expat")
        extra_config+=("--without-libexpat-prefix")

        do_gdb_backend \
            buildtype=cross \
            host="${CT_HOST}" \
            cflags="${CT_CFLAGS_FOR_HOST}" \
            ldflags="${CT_LDFLAGS_FOR_HOST}" \
            prefix="${CT_PREFIX_DIR}" \
            static="${CT_GDB_CROSS_STATIC}" \
            --with-sysroot="${CT_SYSROOT_DIR}"          \
            "${cross_extra_config[@]}"

        if [ "${CT_BUILD_MANUALS}" = "y" ]; then
            CT_DoLog EXTRA "Building and installing the cross-GDB manuals"
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} pdf html
            CT_DoExecLog ALL make install-{pdf,html}-gdb
        fi

        CT_DoLog EXTRA "Installing '.gdbinit' template"
        # See in scripts/build/internals.sh for why we do this
        # TBD GCC 3.x and older not supported
        if [ -f "${CT_SRC_DIR}/gcc/gcc/BASE-VER" ]; then
            gcc_version=$(cat "${CT_SRC_DIR}/gcc/gcc/BASE-VER")
        else
            gcc_version=$(sed -r -e '/version_string/!d; s/^.+= "([^"]+)".*$/\1/;'   \
                               "${CT_SRC_DIR}/gcc/gcc/version.c"   \
                         )
        fi
        sed -r                                                  \
               -e "s:@@PREFIX@@:${CT_PREFIX_DIR}:;"             \
               -e "s:@@VERSION@@:${gcc_version}:;"              \
               "${CT_LIB_DIR}/scripts/build/debug/gdbinit.in"   \
               >"${CT_PREFIX_DIR}/share/gdb/gdbinit"

        CT_Popd
        CT_EndStep
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        local -a native_extra_config
        local subdir

        CT_DoStep INFO "Installing native gdb"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-gdb-native"

        native_extra_config+=("--program-prefix=")

        # gdbserver gets enabled by default with gdb
        # since gdbserver was promoted to top-level
        if [ "${CT_GDB_GDBSERVER_TOPLEVEL}" = "y" ]; then
            native_extra_config+=("--disable-gdbserver")
        fi

        # GDB on Mingw depends on PDcurses, not ncurses
        if [ "${CT_MINGW32}" != "y" ]; then
            native_extra_config+=("--with-curses")
        fi

        if [ "${CT_GDB_NATIVE_BUILD_IPA_LIB}" = "y" ]; then
            native_extra_config+=("--enable-inprocess-agent")
        else
            native_extra_config+=("--disable-inprocess-agent")
        fi

        export ac_cv_func_strncmp_works=yes

        # TBD do we need all these?
        native_extra_config+=(
            --without-uiout
            --disable-gdbtk
            --without-x
            --disable-sim
            --without-included-gettext
            --without-develop
            --sysconfdir=/etc
            --localstatedir=/var
        )

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
        extra_config+=("--with-expat")
        extra_config+=("--without-libexpat-prefix")

        do_gdb_backend \
            buildtype=native \
            subdir=${subdir} \
            host="${CT_TARGET}" \
            cflags="${CT_ALL_TARGET_CFLAGS}" \
            ldflags="${CT_ALL_TARGET_LDFLAGS}" \
            static="${CT_GDB_NATIVE_STATIC}" \
            static_libstdc="${CT_GDB_NATIVE_STATIC_LIBSTDC}" \
            prefix=/usr \
            destdir="${CT_DEBUGROOT_DIR}" \
            "${native_extra_config[@]}"

        unset ac_cv_func_strncmp_works

        CT_Popd
        CT_EndStep # native gdb build
    fi

    if [ "${CT_GDB_GDBSERVER}" = "y" ]; then
        local -a native_extra_config
        local subdir

        if [ "${CT_GDB_GDBSERVER_TOPLEVEL}" != "y" ]; then
            subdir=gdb/gdbserver/
        else
            native_extra_config+=("--disable-gdb")
        fi

        CT_DoStep INFO "Installing gdb server"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-gdb-server"

        native_extra_config+=("--program-prefix=")
        native_extra_config+=("--enable-gdbserver")

        if [ "${CT_GDB_NATIVE_BUILD_IPA_LIB}" = "y" ]; then
            native_extra_config+=("--enable-inprocess-agent")
        else
            native_extra_config+=("--disable-inprocess-agent")
        fi

        export ac_cv_func_strncmp_works=yes

        # TBD do we need all these?
        native_extra_config+=(
            --without-uiout
            --disable-gdbtk
            --without-x
            --disable-sim
            --without-included-gettext
            --without-develop
            --sysconfdir=/etc
            --localstatedir=/var
        )

        do_gdb_backend \
            buildtype=native \
            subdir=${subdir} \
            host="${CT_TARGET}" \
            cflags="${CT_ALL_TARGET_CFLAGS}" \
            ldflags="${CT_ALL_TARGET_LDFLAGS}" \
            static="${CT_GDB_NATIVE_STATIC}" \
            static_libstdcxx="${CT_GDB_NATIVE_STATIC_LIBSTDCXX}" \
            prefix=/usr \
            destdir="${CT_DEBUGROOT_DIR}" \
            "${native_extra_config[@]}"

        unset ac_cv_func_strncmp_works

        CT_Popd
        CT_EndStep # gdb server build
    fi
}

do_gdb_backend()
{
    local host prefix destdir cflags ldflags static buildtype subdir
    local -a extra_config

    for arg in "$@"; do
        case "$arg" in
            --*)
                extra_config+=("${arg}")
                ;;
            *)
                eval "${arg// /\\ }"
                ;;
        esac
    done

    [ -n "${CT_PKGVERSION}" ] && extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")

    # Disable binutils options when building from the binutils-gdb repo.
    extra_config+=("--disable-binutils")
    extra_config+=("--disable-ld")
    extra_config+=("--disable-gas")

    case "${CT_THREADS}" in
        none)   extra_config+=("--disable-threads");;
        *)      extra_config+=("--enable-threads");;
    esac

    if [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ]; then
        extra_config+=("--disable-nls")
    fi

    if [ "${static}" = "y" ]; then
        cflags+=" -static"
        ldflags+=" -static"
        # There is no static libsource-highlight
        extra_config+=("--disable-source-highlight")
    fi
    if [ "${static_libstdcxx}" = "y" ]; then
        ldflags+=" -static-libgcc"
        ldflags+=" -static-libstdc++"
        # libsource-highlight is a dynamic library that uses exception
        # exceptions are handled by libstdc++
        # this combination is very buggy, so configure don't use it and abort
        extra_config+=("--disable-source-highlight")
    fi


    # Fix up whitespace. Some older GDB releases (e.g. 6.8a) get confused if there
    # are multiple consecutive spaces: sub-configure scripts replace them with a
    # single space and then complain that $CC value changed from that in
    # the master directory.
    cflags=`echo ${cflags}`
    ldflags=`echo ${ldflags}`

    CT_DoLog EXTRA "Configuring ${buildtype} gdb"
    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # Run configure/make in the matching subdirectory so that any fixups
    # prepared in a given subdirectory apply.
    if [ -n "${subdir}" ]; then
        CT_mkdir_pushd "${subdir}"
    fi

    # TBD: is passing CPP/CC/CXX/LD needed? GCC should be determining this automatically from the triplets
    CT_DoExecLog CFG                                \
    CPP="${host}-cpp"                               \
    CC="${host}-gcc"                                \
    CXX="${host}-g++"                               \
    LD="${host}-ld"                                 \
    CFLAGS="${cflags}"                              \
    CXXFLAGS="${cflags}"                            \
    LDFLAGS="${ldflags}"                            \
    ${CONFIG_SHELL}                                 \
    "${CT_SRC_DIR}/gdb/${subdir}configure"          \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --target=${CT_TARGET}                       \
        --prefix="${prefix}"                        \
        --with-build-sysroot="${CT_SYSROOT_DIR}"    \
        --includedir="${CT_HEADERS_DIR}"            \
        --disable-werror                            \
        "${extra_config[@]}"                        \

    CT_DoLog EXTRA "Building ${buildtype} gdb"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing ${buildtype} gdb"
    CT_DoExecLog ALL make install ${destdir:+DESTDIR="${destdir}"}

    if [ -n "${subdir}" ]; then
        CT_Popd
    fi
}
