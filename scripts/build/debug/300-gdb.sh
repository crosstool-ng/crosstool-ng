# Build script for the gdb debug facility

# The version of ncurses to use. Yes, it's hard-coded.
# It's used only internally by crosstool-NG, and is
# not exposed outside, so we don't care about providing
# config options for this.
CT_DEBUG_GDB_NCURSES_VERSION="5.7"

do_debug_gdb_parts() {
    do_gdb=
    do_ncurses=

    if [ "${CT_GDB_CROSS}" = y ]; then
        do_gdb=y
    fi

    if [ "${CT_GDB_GDBSERVER}" = "y" ]; then
        do_gdb=y
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        do_gdb=y
        do_ncurses=y
    fi
}

do_debug_gdb_get() {
    do_debug_gdb_parts

    if [ "${do_gdb}" = "y" ]; then
        CT_GetFile "gdb-${CT_GDB_VERSION}"                          \
                   {ftp,http}://ftp.gnu.org/pub/gnu/gdb             \
                   ftp://sources.redhat.com/pub/gdb/{,old-}releases
    fi

    if [ "${do_ncurses}" = "y" ]; then
        CT_GetFile "ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}" .tar.gz  \
                   {ftp,http}://ftp.gnu.org/pub/gnu/ncurses \
                   ftp://invisible-island.net/ncurses
    fi
}

do_debug_gdb_extract() {
    do_debug_gdb_parts

    if [ "${do_gdb}" = "y" ]; then
        CT_Extract "gdb-${CT_GDB_VERSION}"
        CT_Patch "gdb" "${CT_GDB_VERSION}"
    fi

    if [ "${do_ncurses}" = "y" ]; then
        CT_Extract "ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}"
        CT_Patch "ncurses" "${CT_DEBUG_GDB_NCURSES_VERSION}"
    fi
}

do_debug_gdb_build() {
    local -a extra_config

    gdb_src_dir="${CT_SRC_DIR}/gdb-${CT_GDB_VERSION}"

    # Version 6.3 and below behave badly with gdbmi
    case "${CT_GDB_VERSION}" in
        6.2*|6.3)   extra_config+=("--disable-gdbmi");;
    esac

    if [ "${CT_GDB_CROSS}" = "y" ]; then
        local -a cross_extra_config

        CT_DoStep INFO "Installing cross-gdb"
        CT_DoLog EXTRA "Configuring cross-gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-cross"
        cd "${CT_BUILD_DIR}/build-gdb-cross"

        cross_extra_config=("${extra_config[@]}")
        if [ "${CT_GDB_CROSS_USE_GMP_MPFR}" = "y" ]; then
            cross_extra_config+=("--with-gmp=${CT_PREFIX_DIR}")
            cross_extra_config+=("--with-mpfr=${CT_PREFIX_DIR}")
        fi
        if [ "${CT_GDB_CROSS_USE_MPC}" = "y" ]; then
            cross_extra_config+=("--with-mpc=${CT_PREFIX_DIR}")
        fi
        case "${CT_THREADS}" in
            none)   cross_extra_config+=("--disable-threads");;
            *)      cross_extra_config+=("--enable-threads");;
        esac

        CC_for_gdb=
        LD_for_gdb=
        if [ "${CT_GDB_CROSS_STATIC}" = "y" ]; then
            CC_for_gdb="gcc -static"
            LD_for_gdb="ld -static"
        fi

        gdb_cross_configure="${gdb_src_dir}/configure"

        CT_DoLog DEBUG "Extra config passed: '${cross_extra_config[*]}'"

        CC="${CC_for_gdb}"                              \
        LD="${LD_for_gdb}"                              \
        CT_DoExecLog ALL                                \
        "${gdb_cross_configure}"                        \
            --build=${CT_BUILD}                         \
            --host=${CT_HOST}                           \
            --target=${CT_TARGET}                       \
            --prefix="${CT_PREFIX_DIR}"                 \
            --with-build-sysroot="${CT_SYSROOT_DIR}"    \
            --disable-werror                            \
            "${cross_extra_config[@]}"

        CT_DoLog EXTRA "Building cross-gdb"
        CT_DoExecLog ALL make ${PARALLELMFLAGS}

        CT_DoLog EXTRA "Installing cross-gdb"
        CT_DoExecLog ALL make install

        CT_EndStep
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        local -a native_extra_config
        local -a ncurses_opt

        CT_DoStep INFO "Installing native gdb"

        CT_DoLog EXTRA "Building static target ncurses"

        [ "${CT_CC_LANG_CXX}" = "y" ] || ncurses_opts+=("--without-cxx" "--without-cxx-binding")
        [ "${CT_CC_LANG_ADA}" = "y" ] || ncurses_opts+=("--without-ada")

        mkdir -p "${CT_BUILD_DIR}/build-ncurses-build-tic"
        cd "${CT_BUILD_DIR}/build-ncurses-build-tic"

        # Use build = CT_REAL_BUILD so that configure thinks it is
        # cross-compiling, and thus will use the ${CT_BUILD}-*
        # tools instead of searching for the native ones...
        CT_DoExecLog ALL                                                    \
        "${CT_SRC_DIR}/ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}/configure"   \
            --build=${CT_BUILD}                                             \
            --host=${CT_BUILD}                                              \
            --prefix=/usr                                                   \
            --without-shared                                                \
            --enable-symlinks                                               \
            --with-build-cc=${CT_REAL_BUILD}-gcc                            \
            --with-build-cpp=${CT_REAL_BUILD}-gcc                           \
            --with-build-cflags="${CT_CFLAGS_FOR_HOST}"                     \
            "${ncurses_opts[@]}"

        # Under some operating systems (eg. Winblows), there is an
        # extension appended to executables. Find that.
        tic_ext=$(grep -E '^x[[:space:]]*=' progs/Makefile |sed -r -e 's/^.*=[[:space:]]*//;')

        CT_DoExecLog ALL make ${PARALLELMFLAGS} -C include
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -C progs "tic${tic_ext}"

        CT_DoExecLog ALL install -d -m 0755 "${CT_PREFIX_DIR}/bin"
        CT_DoExecLog ALL install -m 0755 "progs/tic${tic_ext}" "${CT_PREFIX_DIR}/buildtools"

        mkdir -p "${CT_BUILD_DIR}/build-ncurses"
        cd "${CT_BUILD_DIR}/build-ncurses"

        CT_DoExecLog ALL                                                    \
        "${CT_SRC_DIR}/ncurses-${CT_DEBUG_GDB_NCURSES_VERSION}/configure"   \
            --build=${CT_BUILD}                                             \
            --host=${CT_TARGET}                                             \
            --with-build-cc=${CT_BUILD}-gcc                                 \
            --with-build-cpp=${CT_BUILD}-gcc                                \
            --with-build-cflags="${CT_CFLAGS_FOR_HOST}"                     \
            --prefix="${CT_BUILD_DIR}/ncurses"                              \
            --without-shared                                                \
            --without-sysmouse                                              \
            --without-progs                                                 \
            --enable-termcap                                                \
            "${ncurses_opts[@]}"

        CT_DoExecLog ALL make ${PARALLELMFLAGS}

        CT_DoExecLog ALL make install

        # We no longer need the temporary tic. Remove it
        CT_DoExecLog DEBUG rm -fv "${CT_PREFIX_DIR}/bin/tic"

        CT_DoLog EXTRA "Configuring native gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-native"
        cd "${CT_BUILD_DIR}/build-gdb-native"

        native_extra_config=("${extra_config[@]}")
        case "${CT_THREADS}" in
            none)   native_extra_config+=("--disable-threads");;
            *)      native_extra_config+=("--enable-threads");;
        esac
        if [ "${CT_GDB_NATIVE_USE_GMP_MPFR}" = "y" ]; then
            native_extra_config+=("--with-gmp=${CT_SYSROOT_DIR}/usr")
            native_extra_config+=("--with-mpfr=${CT_SYSROOT_DIR}/usr")
        fi

        if [ "${CT_GDB_NATIVE_STATIC}" = "y" ]; then
            CC_for_gdb="${CT_TARGET}-gcc -static"
            LD_for_gdb="${CT_TARGET}-ld -static"
        else
            CC_for_gdb="${CT_TARGET}-gcc"
            LD_for_gdb="${CT_TARGET}-ld"
        fi

        export ac_cv_func_strncmp_works=yes

        gdb_native_CFLAGS="-I${CT_BUILD_DIR}/ncurses/include -L${CT_BUILD_DIR}/ncurses/lib"

        CT_DoLog DEBUG "Extra config passed: '${native_extra_config[*]}'"

        CC="${CC_for_gdb}"                              \
        LD="${LD_for_gdb}"                              \
        CFLAGS="${gdb_native_CFLAGS}"                   \
        CT_DoExecLog ALL                                \
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
        CT_DoExecLog ALL make ${PARALLELMFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing native gdb"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

        # Building a native gdb also builds a gdbserver
        find "${CT_DEBUGROOT_DIR}" -type f -name gdbserver -exec rm -fv {} \; 2>&1 |CT_DoLog ALL

        unset ac_cv_func_strncmp_works

        CT_DoLog EXTRA "Cleaning up ncurses"
        cd "${CT_BUILD_DIR}/build-ncurses"
        CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" uninstall

        CT_DoExecLog DEBUG rm -rf "${CT_BUILD_DIR}/ncurses"

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

        LDFLAGS="${gdbserver_LDFLAGS}"                  \
        CT_DoExecLog ALL                                \
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
        CT_DoExecLog ALL make ${PARALLELMFLAGS} CC=${CT_TARGET}-${CT_CC}

        CT_DoLog EXTRA "Installing gdbserver"
        CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" install

        CT_EndStep
    fi
}
