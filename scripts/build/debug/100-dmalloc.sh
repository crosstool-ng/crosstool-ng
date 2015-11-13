# Build script for the dmalloc debug library facility

do_debug_dmalloc_get() {
    CT_GetFile "dmalloc-${CT_DMALLOC_VERSION}" http://dmalloc.com/releases/
}

do_debug_dmalloc_extract() {
    CT_Extract "dmalloc-${CT_DMALLOC_VERSION}"
    CT_Patch "dmalloc" "${CT_DMALLOC_VERSION}"
}

do_debug_dmalloc_build() {
    local -a lib_links
    local -a extra_config

    CT_DoStep INFO "Installing dmalloc"
    CT_DoLog EXTRA "Configuring dmalloc"

    mkdir -p "${CT_BUILD_DIR}/build-dmalloc"
    cd "${CT_BUILD_DIR}/build-dmalloc"

    lib_links+=("dmalloc")
    case "${CT_CC_LANG_CXX}" in
        y)  extra_config+=("--enable-cxx");
            lib_links+=("dmalloccxx")
            ;;
        *)  extra_config+=("--disable-cxx");;
    esac
    case "${CT_THREADS}" in
        none)   extra_config+=("--disable-threads");;
        *)      extra_config+=("--enable-threads")
                lib_links+=("dmallocth")
                if [ "${CT_CC_LANG_CXX}" = "y" ]; then
                    lib_links+=("dmallocthcxx")
                fi
                ;;
    esac
    case "${CT_SHARED_LIBS}" in
        y)  extra_config+=("--enable-shlib");;
        *)  extra_config+=("--disable-shlib");;
    esac

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    CT_DoExecLog CFG                                            \
    CC="${CT_TARGET}-gcc"                                       \
    CXX="${CT_TARGET}-g++"                                      \
    CPP="${CT_TARGET}-cpp"                                      \
    LD="${CT_TARGET}-ld"                                        \
    AR="${CT_TARGET}-ar"                                        \
    CFLAGS=-fPIC                                                \
    "${CT_SRC_DIR}/dmalloc-${CT_DMALLOC_VERSION}/configure"     \
        --prefix=/usr                                           \
        --build="${CT_BUILD}"                                   \
        --host="${CT_TARGET}"                                   \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building dmalloc"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing dmalloc"
    CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" installincs installlib
    CT_DoExecLog ALL make DESTDIR="${CT_DEBUGROOT_DIR}" installutil

    if [ "${CT_SHARED_LIBS}" = "y" ]; then
        # Make symlinks
        CT_DoLog ALL "Making dmalloc library symlinks"
        maj_ver=${CT_DMALLOC_VERSION/\.?\.?/}
        CT_Pushd "${CT_SYSROOT_DIR}/usr/lib"
        for j in "${lib_links[@]}"; do
            CT_DoExecLog ALL ln -s "lib${j}.so" \
                "lib${j}.so.${CT_DMALLOC_VERSION}"
            CT_DoExecLog ALL ln -s "lib${j}.so" "lib${j}.so.${maj_ver}"
        done
        CT_Popd
    fi

    CT_EndStep
}
