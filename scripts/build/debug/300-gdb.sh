# Build script for the gdb debug facility

is_enabled="${CT_GDB}"

do_print_filename() {
    [ "${CT_GDB}" = "y" ] || return 0
    echo "gdb$(do_debug_gdb_suffix)"
    [ "${CT_GDB_NATIVE}" = "y" ] && echo "ncurses-${CT_NCURSES_VERSION}"
}

do_debug_gdb_suffix() {
    case "${CT_GDB_VERSION}" in
        snapshot)   ;;
        *)          echo "-${CT_GDB_VERSION}";;
    esac
}

do_debug_gdb_get() {
    CT_GetFile "gdb$(do_debug_gdb_suffix)"              \
               {ftp,http}://ftp.gnu.org/pub/gnu/gdb     \
               ftp://sources.redhat.com/pub/gdb/{{,old-}releases,snapshots/current}
    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        CT_GetFile "ncurses-${CT_NCURSES_VERSION}"          \
                   {ftp,http}://ftp.gnu.org/pub/gnu/ncurses \
                   ftp://invisible-island.net/ncurses
    fi
}

do_debug_gdb_extract() {
    CT_ExtractAndPatch "gdb$(do_debug_gdb_suffix)"
    [ "${CT_GDB_NATIVE}" = "y" ] && CT_ExtractAndPatch "ncurses-${CT_NCURSES_VERSION}"
}

do_debug_gdb_build() {
    gdb_src_dir="${CT_SRC_DIR}/gdb$(do_debug_gdb_suffix)"

    extra_config=
    # Version 6.3 and below behave badly with gdbmi
    case "${CT_GDB_VERSION}" in
        6.2*|6.3)   extra_config="${extra_config} --disable-gdbmi";;
    esac

    if [ "${CT_GDB_CROSS}" = "y" ]; then
        CT_DoStep INFO "Installing cross-gdb"
        CT_DoLog EXTRA "Configuring cross-gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-cross"
        cd "${CT_BUILD_DIR}/build-gdb-cross"

        CC_for_gdb=
        LD_for_gdb=
        if [ "${CT_GDB_CROSS_STATIC_GDBSERVER}" = "y" ]; then
            CC_for_gdb="gcc -static"
            LD_for_gdb="ld -static"
        fi

        CC="${CC_for_gdb}"                              \
        LD="${LD_forgdb}"                               \
        "${gdb_src_dir}/configure"                      \
            --build=${CT_BUILD}                         \
            --host=${CT_HOST}                           \
            --target=${CT_TARGET}                       \
            --prefix="${CT_PREFIX_DIR}"                 \
            --with-build-sysroot="${CT_SYSROOT_DIR}"    \
            --enable-threads                            \
            ${extra_config}                             2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Building cross-gdb"
        make ${PARALLELMFLAGS}                          2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Installing cross-gdb"
        make install                                    2>&1 |CT_DoLog ALL

        CT_EndStep

        CT_DoStep INFO "Installing gdbserver"
        CT_DoLog EXTRA "Configuring gdbserver"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-gdbserver"
        cd "${CT_BUILD_DIR}/build-gdb-gdbserver"

        # Workaround for bad versions, where the configure
        # script for gdbserver is not executable...
        # Bah, GNU folks strike again... :-(
        chmod +x "${gdb_src_dir}/gdb/gdbserver/configure"

        gdbserver_LDFLAGS=
        if [ "${CT_GDB_CROSS_STATIC_GDBSERVER}" = "y" ]; then
            gdbserver_LDFLAGS=-static
        fi

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
            ${extra_config}                             2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Building gdbserver"
        make ${PARALLELMFLAGS} CC=${CT_TARGET}-${CT_CC} 2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Installing gdbserver"
        make DESTDIR="${CT_DEBUG_INSTALL_DIR}" install  2>&1 |CT_DoLog ALL

        CT_EndStep
    fi

    if [ "${CT_GDB_NATIVE}" = "y" ]; then
        CT_DoStep INFO "Installing native gdb"

        CT_DoStep INFO "Installing ncurses library"
        CT_DoLog EXTRA "Configuring ncurses"
        mkdir -p "${CT_BUILD_DIR}/build-ncurses"
        cd "${CT_BUILD_DIR}/build-ncurses"

        ncurses_opts=
        [ "${CT_CC_LANG_CXX}" = "y" ] || ncurses_opts="${ncurses_opts} --without-cxx --without-cxx-binding"

        "${CT_SRC_DIR}/ncurses-${CT_NCURSES_VERSION}/configure" \
            --build=${CT_BUILD}                                 \
            --host=${CT_TARGET}                                 \
            --with-build-cc=${CT_CC}                            \
            --with-build-cpp=${CT_CC}                           \
            --with-build-cflags="${CT_CFLAGS_FOR_HOST}"         \
            --prefix=/usr                                       \
            --with-shared                                       \
            --without-sysmouse                                  \
            --without-progs                                     \
            --enable-termcap                                    \
            --without-develop                                   \
            ${ncurses_opts}                                     2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Building ncurses"
        make ${PARALLELMFLAGS}  2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Installing ncurses"
        make DESTDIR="${CT_SYSROOT_DIR}" install    2>&1 |CT_DoLog ALL

        CT_EndStep

        CT_DoLog EXTRA "Configuring native gdb"

        mkdir -p "${CT_BUILD_DIR}/build-gdb-native"
        cd "${CT_BUILD_DIR}/build-gdb-native"

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
            --disable-gdbserver                         \
            --without-included-gettext                  \
            ${extra_config}                             2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Building native gdb"
        make ${PARALLELMFLAGS} CC=${CT_TARGET}-${CT_CC} 2>&1 |CT_DoLog ALL

        CT_DoLog EXTRA "Installing native gdb"
        make DESTDIR="${CT_DEBUG_INSTALL_DIR}" install  2>&1 |CT_DoLog ALL

        CT_EndStep
    fi
}
