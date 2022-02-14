# This file adds functions to build the musl C library
# Copyright 2013 Timo TerÃ¤s
# Licensed under the GPL v2. See COPYING in the root of this package

musl_post_cc()
{
    # MUSL creates dynamic linker symlink with absolute path - which works on the
    # target but not on the host. We want our cross-ldd tool to work.
    CT_MultilibFixupLDSO
}

musl_main()
{
    CT_DoStep INFO "Installing C library"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc"
    CT_IterateMultilibs musl_backend_once multilib
    CT_Popd
    CT_EndStep
}

# This backend builds the C library
# Usage: musl_backend param=value [...]
#   Parameter           : Definition                      : Type      : Default
#   multi_*             : as defined in CT_IterateMultilibs     : (varies)  :
musl_backend_once()
{
    local -a extra_cflags
    local -a extra_config
    local src_dir="${CT_SRC_DIR}/musl"
    local multi_dir multi_os_dir multi_root multi_flags multi_index multi_count
    local multilib_dir
    local hdr_install_subdir
    local arg f l

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoStep INFO "Building for multilib ${multi_index}/${multi_count}: '${multi_flags}'"

    multilib_dir="/usr/lib/${multi_os_dir}"
    CT_SanitizeVarDir multilib_dir
    CT_DoExecLog ALL mkdir -p "${multi_root}${multilib_dir}"

    extra_cflags=( ${multi_flags} )

    if [ "${CT_LIBC_MUSL_DEBUG}" = "y" ]; then
        extra_config+=("--enable-debug")
    fi

    if [ "${CT_LIBC_MUSL_WARNINGS}" = "y" ]; then
        extra_config+=("--enable-warnings")
    fi

    case "${CT_SHARED_LIBS}" in
        y) extra_config+=("--enable-shared");;
        *) extra_config+=("--disable-shared");;
    esac

    extra_config+=( "--enable-optimize=${CT_LIBC_MUSL_OPTIMIZE}" )

    # Same problem as with uClibc: different variants sometimes have
    # incompatible headers.
    CT_DoArchMUSLHeaderDir hdr_install_subdir "${multi_flags}"
    if [ -n "${hdr_install_subdir}" ]; then
        extra_config+=( "--includedir=/usr/include/${hdr_install_subdir}" )
    fi

    CT_SymlinkToolsMultilib

    # NOTE: musl handles the build/host/target a little bit differently
    # then one would expect:
    #   build   : not used
    #   host    : same as --target
    #   target  : the machine musl runs on
    CT_DoExecLog CFG                                      \
    CFLAGS="${CT_TARGET_CFLAGS} ${extra_cflags[*]}"       \
    LDFLAGS="${CT_TARGET_LDFLAGS}"                        \
    CROSS_COMPILE="${CT_TARGET}-"                         \
    ${CONFIG_SHELL}                                       \
    ${src_dir}/configure                                  \
        --host="${multi_target}"                          \
        --target="${multi_target}"                        \
        --prefix="/usr"                                   \
        --libdir="${multilib_dir}"                        \
        --disable-gcc-wrapper                             \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make DESTDIR="${multi_root}" install

    # Convert /lib/ld-* symlinks to relative paths so that they are valid
    # both on the host and on the target.
    for f in ${multi_root}/ld-musl-*; do
        [ -L "${f}" ] || continue
        l=$( readlink ${f} )
        case "${l}" in
            ${multilib_dir}/*)
                CT_DoExecLog ALL ln -sf "../${l}" "${f}"
                ;;
        esac
    done

    # Any additional actions for this architecture
    CT_DoArchMUSLPostInstall

    CT_EndStep
}
