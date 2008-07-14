# Build script for the dmalloc debug library facility

is_enabled="${CT_DMALLOC}"

do_print_filename() {
    [ "${CT_DMALLOC}" = "y" ] || return 0
    echo "dmalloc-${CT_DMALLOC_VERSION}"
}

do_debug_dmalloc_get() {
    CT_GetFile "dmalloc-${CT_DMALLOC_VERSION}" http://dmalloc.com/releases/
}

do_debug_dmalloc_extract() {
    CT_ExtractAndPatch "dmalloc-${CT_DMALLOC_VERSION}"
}

do_debug_dmalloc_build() {
    CT_DoStep INFO "Installing dmalloc"
    CT_DoLog EXTRA "Configuring dmalloc"

    mkdir -p "${CT_BUILD_DIR}/build-dmalloc"
    cd "${CT_BUILD_DIR}/build-dmalloc"

    extra_config=
    case "${CT_CC_LANG_CXX}" in
        y)  extra_config="${extra_config} --enable-cxx";;
        *)  extra_config="${extra_config} --disable-cxx";;
    esac
    case "${CT_THREADS_NONE}" in
        y)  extra_config="${extra_config} --disable-threads";;
        *)  extra_config="${extra_config} --enable-threads";;
    esac
    case "${CT_SHARED_LIBS}" in
        y)  extra_config="${extra_config} --enable-shlib";;
        *)  extra_config="${extra_config} --disable-shlib";;
    esac

    CT_DoLog DEBUG "Extra config passed: '${extra_config}'"

    LD="${CT_TARGET}-ld"                                        \
    AR="${CT_TARGET}-ar"                                        \
    CT_DoExecLog ALL                                            \
    "${CT_SRC_DIR}/dmalloc-${CT_DMALLOC_VERSION}/configure"     \
        --prefix=/usr                                           \
        --build="${CT_BUILD}"                                   \
        --host="${CT_TARGET}"                                   \
        ${extra_config}

    CT_DoLog EXTRA "Building dmalloc"
    CT_DoExecLog ALL make 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing dmalloc"
    CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" installincs installlib
    CT_DoExecLog ALL make DESTDIR="${CT_DEBUG_INSTALL_DIR}" installutil

    CT_EndStep
}
