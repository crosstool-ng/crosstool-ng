# Build script for musl-fts

do_musl_fts_get() { :; }
do_musl_fts_extract() { :; }
do_musl_fts_for_build() { :; }
do_musl_fts_for_host() { :; }
do_musl_fts_for_target() { :; }

if [ "${CT_MUSL_FTS_TARGET}" = "y" -o "${CT_MUSL_FTS}" = "y" ]; then

do_musl_fts_get() {
    CT_Fetch MUSL_FTS
}

do_musl_fts_extract() {
    CT_ExtractPatch MUSL_FTS
}

# Build musl-fts for running on target
do_musl_fts_for_target() {
    local -a musl_fts_opts

    CT_DoStep INFO "Installing musl-fts for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-musl-fts-target-${CT_TARGET}"

    do_musl_fts_backend "${musl_fts_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build musl-fts
#     Parameter     : description               : type      : default
do_musl_fts_backend() {
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring musl-fts"

    if [ "${CT_SHARED_LIBS}" = "y" ]; then
        extra_config+=( --enable-shared )
    else
        extra_config+=( --disable-shared )
    fi

    CT_DoExecLog CFG                      \
    CC="${CT_TARGET}-gcc"                 \
    CFLAGS="${CT_ALL_TARGET_CFLAGS}"      \
    LDFLAGS="${CT_ALL_TARGET_LDFLAGS}"    \
    ${CONFIG_SHELL}                       \
    "${CT_SRC_DIR}/musl-fts/configure"    \
        --build=${CT_BUILD}               \
        --host="${CT_TARGET}"             \
        --target=${CT_TARGET}             \
        --prefix=${CT_SYSROOT_DIR_PREFIX} \
        --enable-static                   \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building musl-fts"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing musl-fts"
    CT_DoExecLog ALL make install DESTDIR=${CT_SYSROOT_DIR}
}

fi
