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
    CT_DoStep INFO "Installing musl-fts for target"
    CT_IterateMultilibs do_musl_fts_backend multilib
    CT_EndStep
}

# Build musl-fts
#     Parameter     : description               : type      : default
do_musl_fts_backend() {
    local arg
    local multi_dir        # GCC internal library location for the multilib
    local multi_os_dir     # OS library location for the multilib
    local multi_os_dir_gcc # Same as multi_os_dir, preserved from GCC output
    local multi_flags      # CFLAGS for this multilib
    local multi_root       # Sysroot for this multilib
    local multi_target     # Target tuple, either as reported by GCC or by our guesswork
    local multi_index      # Index of the current multilib
    local multi_count      # Total number of multilibs
    local hdr_install_subdir
    local -a extra_config
    local -a extra_cflags

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-musl-fts-target-${multi_index}-${multi_count}"

    CT_DoStep INFO "Building for multilib ${multi_index}/${multi_count}: '${multi_flags}'"

    multilib_dir="/usr/lib/${multi_os_dir}"
    CT_SanitizeVarDir multilib_dir
    CT_DoExecLog ALL mkdir -p "${multi_root}${multilib_dir}"

    extra_cflags=( ${multi_flags} )

    CT_DoArchMUSLHeaderDir hdr_install_subdir "${multi_flags}"
    if [ -n "${hdr_install_subdir}" ]; then
      extra_config+=( "--includedir=/usr/include/${hdr_install_subdir}" )
    fi

    CT_SymlinkToolsMultilib

    CT_DoLog EXTRA "Configuring musl-fts"
    CT_DoExecLog CFG                     \
        CC="${CT_TARGET}-gcc"            \
        CFLAGS="${extra_cflags[*]}"      \
        ${CONFIG_SHELL}                  \
        ${CT_SRC_DIR}/musl-fts/configure \
            --host="${multi_target}"     \
            --target="${multi_target}"   \
            --prefix="/usr"              \
            --libdir="${multilib_dir}"   \
            "${extra_config[@]}"

    CT_DoLog EXTRA "Building musl-fts"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing musl-fts"
    CT_DoExecLog ALL make DESTDIR="${multi_root}" install

    CT_Popd
}

fi
