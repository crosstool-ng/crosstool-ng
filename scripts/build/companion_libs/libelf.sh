# Build script for libelf

do_libelf_get() { :; }
do_libelf_extract() { :; }
do_libelf() { :; }
do_libelf_target() { :; }

if [ "${CT_LIBELF}" = "y" -o "${CT_LIBELF_TARGET}" = "y" ]; then

do_libelf_get() {
    # The server hosting libelf will return an "HTTP 300 : Multiple Choices"
    # error code if we try to download a file that does not exists there.
    # So we have to request the file with an explicit extension.
    CT_GetFile "libelf-${CT_LIBELF_VERSION}" .tar.gz http://www.mr511.de/software/
}

do_libelf_extract() {
    CT_Extract "libelf-${CT_LIBELF_VERSION}"
    CT_Patch "libelf" "${CT_LIBELF_VERSION}"
}

if [ "${CT_LIBELF}" = "y" ]; then

do_libelf() {
    local -a libelf_opts

    CT_DoStep INFO "Installing libelf"
    mkdir -p "${CT_BUILD_DIR}/build-libelf"
    CT_Pushd "${CT_BUILD_DIR}/build-libelf"

    CT_DoLog EXTRA "Configuring libelf"

    if [ "${CT_COMPLIBS_SHARED}" = "y" ]; then
        libelf_opts+=( --enable-shared --disable-static )
    else
        libelf_opts+=( --disable-shared --enable-static )
    fi

    CT_DoExecLog CFG                                        \
    "${CT_SRC_DIR}/libelf-${CT_LIBELF_VERSION}/configure"   \
        --build=${CT_BUILD}                                 \
        --host=${CT_HOST}                                   \
        --target=${CT_TARGET}                               \
        --prefix="${CT_COMPLIBS_DIR}"                       \
        --enable-compat                                     \
        --enable-elf64                                      \
        --enable-extended-format                            \
        "${libelf_opts[@]}"

    CT_DoLog EXTRA "Building libelf"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing libelf"
    CT_DoExecLog ALL make install

    CT_Popd
    CT_EndStep
}

fi # CT_LIBELF

if [ "${CT_LIBELF_TARGET}" = "y" ]; then

do_libelf_target() {
    CT_DoStep INFO "Installing libelf for the target"
    mkdir -p "${CT_BUILD_DIR}/build-libelf-for-target"
    CT_Pushd "${CT_BUILD_DIR}/build-libelf-for-target"

    CT_DoLog EXTRA "Configuring libelf"
    CC="${CT_TARGET}-gcc"                                   \
    CT_DoExecLog ALL                                        \
    "${CT_SRC_DIR}/libelf-${CT_LIBELF_VERSION}/configure"   \
        --build=${CT_BUILD}                                 \
        --host=${CT_TARGET}                                 \
        --target=${CT_TARGET}                               \
        --prefix=/usr                                       \
        --enable-compat                                     \
        --enable-elf64                                      \
        --enable-shared                                     \
        --enable-extended-format                            \
        --enable-static

    CT_DoLog EXTRA "Building libelf"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing libelf"
    CT_DoExecLog ALL make instroot="${CT_SYSROOT_DIR}" install

    CT_Popd
    CT_EndStep
}

fi # CT_LIBELF_TARGET

fi # CT_LIBELF || CT_LIBELF_TARGET
