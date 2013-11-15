# Build script for the gdb debug facility

# The version of ncurses to use. Yes, it's hard-coded.
# It's used only internally by crosstool-NG, and is
# not exposed outside, so we don't care about providing
# config options for this.
CT_DEBUG_GDB_NCURSES_VERSION="5.9"

# Ditto for the expat library
CT_DEBUG_GDB_EXPAT_VERSION="2.1.0"

do_debug_gdb_parts() {
    need_gdb_src=
    need_ncurses_src=
    need_expat_src=

    if [ "${CT_GDB_CROSS}" = y ]; then
        need_gdb_src=y
    fi

    if [ "${CT_GDB_GDBSERVER}" = "y" ]; then
        need_gdb_src=y
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        need_gdb_src=y
        # GDB on Mingw depends on PDcurses, not ncurses
        if [ "${CT_MINGW32}" != "y" ]; then
            need_ncurses_src=y
        fi
        need_expat_src=y
    fi
}

do_debug_gdb_get() {
    local linaro_version
    local linaro_series
    local linaro_base_url="http://launchpad.net/gdb-linaro"

    # Account for the Linaro versioning
    linaro_version="$( echo "${CT_GDB_VERSION}"      \
                       |sed -r -e 's/^linaro-//;'   \
                     )"
    linaro_series="$( echo "${linaro_version}"      \
                      |sed -r -e 's/-.*//;'         \
                    )"

    do_debug_gdb_parts

    if [ "${need_gdb_src}" = "y" ]; then
        if [ "${CT_GDB_CUSTOM}" = "y" ]; then
            CT_GetCustom "gdb" "${CT_GDB_VERSION}" "${CT_GDB_CUSTOM_LOCATION}"
        else
            CT_GetFile "gdb-${CT_GDB_VERSION}"                          \
                       {ftp,http}://ftp.gnu.org/pub/gnu/gdb             \
                       ftp://sources.redhat.com/pub/gdb/{,old-}releases \
                       "${linaro_base_url}/${linaro_series}/${linaro_version}/+download"
        fi
    fi

    if [ "${need_ncurses_src}" = "y" ]; then
        CT_GetFile "ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}" .tar.gz  \
                   {ftp,http}://ftp.gnu.org/pub/gnu/ncurses \
                   ftp://invisible-island.net/ncurses
    fi

    if [ "${need_expat_src}" = "y" ]; then
        CT_GetFile "expat-${CT_DEBUG_GDB_EXPAT_VERSION}" .tar.gz    \
                   http://downloads.sourceforge.net/project/expat/expat/${CT_DEBUG_GDB_EXPAT_VERSION}
    fi
}

do_debug_gdb_extract() {
    do_debug_gdb_parts

    if [ "${need_gdb_src}" = "y" ]; then
        # If using custom directory location, nothing to do
        if [    "${CT_GDB_CUSTOM}" = "y" \
             -a -d "${CT_SRC_DIR}/gdb-${CT_GDB_VERSION}" ]; then
            return 0
        fi
        CT_Extract "gdb-${CT_GDB_VERSION}"
        CT_Patch "gdb" "${CT_GDB_VERSION}"
    fi

    if [ "${need_ncurses_src}" = "y" ]; then
        CT_Extract "ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}"
        CT_DoExecLog ALL chmod -R u+w "${CT_SRC_DIR}/ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}"
        CT_Patch "ncurses" "${CT_DEBUG_GDB_NCURSES_VERSION}"
    fi

    if [ "${need_expat_src}" = "y" ]; then
        CT_Extract "expat-${CT_DEBUG_GDB_EXPAT_VERSION}"
        CT_Patch "expat" "${CT_DEBUG_GDB_EXPAT_VERSION}"
    fi
}

do_debug_gdb_build() {
    local -a extra_config

    do_debug_gdb_parts

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
        cross_extra_config+=("--enable-expat")
        cross_extra_config+=("--with-expat=yes")
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
            if [ -f "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/gcc/BASE-VER" ]; then
                gcc_version=$( cat "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/gcc/BASE-VER" )
            else
                gcc_version=$( sed -r -e '/version_string/!d; s/^.+= "([^"]+)".*$/\1/;' \
                                   "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/gcc/version.c"   \
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
        local -a ncurses_opt
        local -a gdb_native_CFLAGS

        CT_DoStep INFO "Installing native gdb"

        native_extra_config=("${extra_config[@]}")

        # GDB on Mingw depends on PDcurses, not ncurses
        if [ "${CT_MINGW32}" != "y" ]; then
            CT_DoLog EXTRA "Building static target ncurses"

            CT_mkdir_pushd "${CT_BUILD_DIR}/build-ncurses-target-${CT_TARGET}"
            do_gdb_ncurses_backend host="${CT_TARGET}"                      \
                                   prefix="${CT_BUILD_DIR}/static-target"   \
                                   cflags="${CT_CFLAGS_FOR_HOST}"           \
                                   ldflags=""
            CT_Popd
            native_extra_config+=("--with-curses")
            # There's no better way to tell gdb where to find -lcurses... :-(
            gdb_native_CFLAGS+=("-I${CT_BUILD_DIR}/static-target/include")
            gdb_native_CFLAGS+=("-L${CT_BUILD_DIR}/static-target/lib")
        fi # need_ncurses_src

        # Build libexpat
        CT_DoLog EXTRA "Building static target expat"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-expat-target-${CT_TARGET}"
        do_gdb_expat_backend host="${CT_TARGET}"                    \
                             prefix="${CT_BUILD_DIR}/static-target" \
                             cflags=""                              \
                             ldflags=""
        CT_Popd
        native_extra_config+=("--with-expat")
        native_extra_config+=("--with-libexpat-prefix=${CT_BUILD_DIR}/static-target")

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
        CT_DoExecLog ALL make ${JOBSFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing native gdb"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

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
        CT_DoExecLog ALL make ${JOBSFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing gdbserver"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

        CT_EndStep
    fi
}

# Build libncurses
#   Parameter     : description               : type      : default
#   host          : machine to run on         : tuple     : (none)
#   prefix        : prefix to install into    : dir       : (none)
#   cflags        : cflags to use             : string    : (empty)
#   ldflags       : ldflags to use            : string    : (empty)
do_gdb_ncurses_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    [ "${CT_CC_LANG_CXX}" = "y" ] || ncurses_opts+=("--without-cxx" "--without-cxx-binding")
    [ "${CT_CC_LANG_ADA}" = "y" ] || ncurses_opts+=("--without-ada")

    CT_mkdir_pushd "build-tic"

    # We need a tic that runs on build, not on host nor on target
    # Use build = CT_REAL_BUILD so that configure thinks it is
    # cross-compiling, and thus will use the ${CT_BUILD}-*
    # tools instead of searching for the native ones...
    CT_DoExecLog CFG                                                    \
    "${CT_SRC_DIR}/ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}/configure"   \
        --build=${CT_BUILD}                                             \
        --host=${CT_BUILD}                                              \
        --prefix=/usr                                                   \
        --enable-symlinks                                               \
        --with-build-cc=${CT_REAL_BUILD}-gcc                            \
        --with-build-cpp=${CT_REAL_BUILD}-gcc                           \
        --with-build-cflags="${CT_CFLAGS_FOR_HOST}"                     \
        "${ncurses_opts[@]}"

    # ncurses insists on linking tic statically. It does not work
    # on some OSes (eg. MacOS-X/Darwin/whatever-you-call-it).
    CT_DoExecLog DEBUG sed -r -i -e 's/-static//g;' "progs/Makefile"

    # Under some operating systems (eg. Winblows), there is an
    # extension appended to executables. Find that.
    tic_ext=$(grep -E '^x[[:space:]]*=' progs/Makefile |sed -r -e 's/^.*=[[:space:]]*//;')

    CT_DoExecLog ALL make ${JOBSFLAGS} -C include
    CT_DoExecLog ALL make ${JOBSFLAGS} -C progs "tic${tic_ext}"

    CT_DoExecLog ALL install -d -m 0755 "${CT_BUILDTOOLS_PREFIX_DIR}/bin"
    CT_DoExecLog ALL install -m 0755 "progs/tic${tic_ext}" "${CT_BUILDTOOLS_PREFIX_DIR}/bin"

    CT_Popd

    CT_mkdir_pushd "ncurses"

    CT_DoExecLog CFG                                                    \
    TIC_PATH="${CT_BUILDTOOLS_PREFIX_DIR}/bin/tic${tic_ext}"            \
    "${CT_SRC_DIR}/ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}/configure"   \
        --build=${CT_BUILD}                                             \
        --host=${host}                                                  \
        --with-build-cc=${CT_BUILD}-gcc                                 \
        --with-build-cpp=${CT_BUILD}-gcc                                \
        --with-build-cflags="${CT_CFLAGS_FOR_HOST}"                     \
        --prefix="${prefix}"                                            \
        --without-shared                                                \
        --without-sysmouse                                              \
        --without-progs                                                 \
        --enable-termcap                                                \
        "${ncurses_opts[@]}"

    CT_DoExecLog ALL make ${JOBSFLAGS}
    CT_DoExecLog ALL make install

    CT_Popd
}

# Build libexpat
#   Parameter     : description               : type      : default
#   host          : machine to run on         : tuple     : (none)
#   prefix        : prefix to install into    : dir       : (none)
#   cflags        : cflags to use             : string    : (empty)
#   ldflags       : ldflags to use            : string    : (empty)
do_gdb_expat_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoExecLog CFG                                                \
    "${CT_SRC_DIR}/expat-${CT_DEBUG_GDB_EXPAT_VERSION}/configure"   \
        --build=${CT_BUILD}                                         \
        --host=${host}                                              \
        --prefix="${prefix}"                                        \
        --enable-static                                             \
        --disable-shared

    CT_DoExecLog ALL make ${JOBSFLAGS}
    CT_DoExecLog ALL make install
}
