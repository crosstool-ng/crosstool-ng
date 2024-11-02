# Build script for the mold linker

do_linker_mold_get() {
    CT_Fetch MOLD
}

do_linker_mold_extract() {
    CT_ExtractPatch MOLD
}

do_linker_mold_build() {
    local target_dir="${CT_PREFIX_DIR}/${CT_TARGET}"

    CT_DoStep INFO "Installing mold for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-mold"

    CT_DoLog EXTRA "Configuring mold for host"
    CT_DoExecLog CFG                                           \
    CC="${CT_HOST}-gcc"                                        \
    CXX="${CT_HOST}-g++"                                       \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                             \
    LDFLAGS="${CT_LDFLAGS_FOR_HOST}"                           \
    cmake "${CT_SRC_DIR}/mold"                                 \
        -DBUILD_TESTING=OFF                                    \
        -DMOLD_MOSTLY_STATIC=ON                                \
        -DCMAKE_BUILD_TYPE=Release

    CT_DoLog EXTRA "Building mold for host"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing mold for host"
    mkdir -p "${target_dir}/bin"
    cp mold "${target_dir}/bin"
    ln -s mold "${target_dir}/bin/ld.mold"
    mkdir -p "${target_dir}/lib/mold"
    cp mold-wrapper.so "${target_dir}/lib/mold"

    CT_Popd
    CT_EndStep
}
