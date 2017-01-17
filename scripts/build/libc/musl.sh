# This file adds functions to build the musl C library
# Copyright 2013 Timo TerÃ¤s
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    if [ "${CT_LIBC_MUSL_CUSTOM}" = "y" ]; then
        CT_GetCustom "musl" "${CT_LIBC_MUSL_CUSTOM_VERSION}" \
            "${CT_LIBC_MUSL_CUSTOM_LOCATION}"
    else # ! custom location
        CT_GetFile "musl-${CT_LIBC_VERSION}" http://www.musl-libc.org/releases
    fi # ! custom location
}

do_libc_extract() {
    CT_Extract "musl-${CT_LIBC_VERSION}"
    CT_Patch "musl" "${CT_LIBC_VERSION}"
}

# Build and install headers and start files
do_libc_start_files() {
    # Start files and Headers should be configured the same way as the
    # final libc, but built and installed differently.
    do_libc_backend libc_mode=startfiles
}

# This function builds and install the full C library
do_libc() {
    do_libc_backend libc_mode=final
}

do_libc_post_cc() {
    :
}

do_libc_backend() {
    local libc_mode
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    case "${libc_mode}" in
        startfiles)     CT_DoStep INFO "Installing C library headers & start files";;
        final)          CT_DoStep INFO "Installing C library";;
        *)              CT_Abort "Unsupported (or unset) libc_mode='${libc_mode}'";;
    esac

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc-${libc_mode}"
    CT_IterateMultilibs do_libc_backend_once multilib libc_mode="${libc_mode}"
    CT_Popd
    CT_EndStep
}

# This backend builds the C library
# Usage: do_libc_backend param=value [...]
#   Parameter           : Definition                      : Type      : Default
#   libc_mode           : 'startfiles' or 'final'         : string    : (none)
do_libc_backend_once() {
    local libc_mode
    local -a extra_cflags
    local -a extra_config
    local src_dir="${CT_SRC_DIR}/${CT_LIBC}-${CT_LIBC_VERSION}"
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

    # From buildroot:
    # gcc constant folding bug with weak aliases workaround
    # See http://www.openwall.com/lists/musl/2014/05/15/1
    if [ "${CT_CC_GCC_4_9_or_later}" = "y" ]; then
        extra_cflags+=("-fno-toplevel-reorder")
    fi

    if [ "${CT_LIBC_MUSL_DEBUG}" = "y" ]; then
        extra_config+=("--enable-debug")
    fi

    if [ "${CT_LIBC_MUSL_WARNINGS}" = "y" ]; then
        extra_config+=("--enable-warnings")
    fi

    extra_config+=( "--enable-optimize=${CT_LIBC_MUSL_OPTIMIZE}" )

    # Same problem as with uClibc: different variants sometimes have
    # incompatible headers.
    CT_DoArchMUSLHeaderDir hdr_install_subdir "${multi_flags}"
    if [ -n "${hdr_install_subdir}" ]; then
        extra_config+=( "--includedir=/usr/include/${hdr_install_subdir}" )
    fi

    # NOTE: musl handles the build/host/target a little bit differently
    # then one would expect:
    #   build   : not used
    #   host    : same as --target
    #   target  : the machine musl runs on
    CT_DoExecLog CFG                                      \
    CFLAGS="${extra_cflags[*]}"                           \
    CROSS_COMPILE="${CT_TARGET}-"                         \
    ${src_dir}/configure                                  \
        --host="${multi_target}"                          \
        --target="${multi_target}"                        \
        --prefix="/usr"                                   \
        --libdir="${multilib_dir}"                        \
        --disable-gcc-wrapper                             \
        "${extra_config[@]}"

    if [ "${libc_mode}" = "startfiles" ]; then
        CT_DoLog EXTRA "Installing C library headers"
        CT_DoExecLog ALL make DESTDIR="${multi_root}" install-headers
        CT_DoLog EXTRA "Building C library start files"
        CT_DoExecLog ALL make DESTDIR="${multi_root}" \
            obj/crt/crt1.o obj/crt/crti.o obj/crt/crtn.o
        CT_DoLog EXTRA "Installing C library start files"
        CT_DoExecLog ALL cp -av obj/crt/crt*.o "${multi_root}${multilib_dir}"
        CT_DoExecLog ALL ${CT_TARGET}-${CT_CC} -nostdlib \
            -nostartfiles -shared -x c /dev/null -o "${multi_root}${multilib_dir}/libc.so"
    fi
    if [ "${libc_mode}" = "final" ]; then
        CT_DoLog EXTRA "Cleaning up start files"
        CT_DoExecLog ALL rm -f "${multi_root}${multilib_dir}/crt1.o" \
            "${multi_root}${multilib_dir}/crti.o" \
            "${multi_root}${multilib_dir}/crtn.o" \
            "${multi_root}${multilib_dir}/libc.so"

        CT_DoLog EXTRA "Building C library"
        CT_DoExecLog ALL make ${JOBSFLAGS}

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
    fi

    CT_EndStep
}
