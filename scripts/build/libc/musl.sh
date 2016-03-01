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

do_libc_check_config() {
    :
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

# This backend builds the C library
# Usage: do_libc_backend param=value [...]
#   Parameter           : Definition                      : Type      : Default
#   libc_mode           : 'startfiles' or 'final'         : string    : (none)
do_libc_backend() {
    local libc_mode
    local -a extra_cflags
    local -a extra_config
    local src_dir="${CT_SRC_DIR}/${CT_LIBC}-${CT_LIBC_VERSION}"
    local libc_headers libc_startfiles libc_full

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    case "${libc_mode}" in
        startfiles)
            CT_DoStep INFO "Installing C library headers & start files"
            libc_headers=y
            libc_startfiles=y
            libc_full=
            ;;
        final)
            CT_DoStep INFO "Installing C library"
            libc_headers=
            libc_startfiles=
            libc_full=y
            ;;
        *)  CT_Abort "Unsupported (or unset) libc_mode='${libc_mode}'";;
    esac

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

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc-${libc_mode}"

    # NOTE: musl handles the build/host/target a little bit differently
    # then one would expect:
    #   build   : not used
    #   host    : the machine building musl
    #   target  : the machine musl runs on
    CT_DoExecLog CFG                \
    CFLAGS="${extra_cflags[@]}"     \
    CROSS_COMPILE="${CT_TARGET}-"   \
    ${src_dir}/configure            \
        --host="${CT_TARGET}"       \
        --target="${CT_TARGET}"     \
        --prefix="/usr"             \
        --disable-gcc-wrapper       \
        "${extra_config[@]}"

    if [ "${libc_headers}" = "y" ]; then
        CT_DoLog EXTRA "Installing C library headers"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" install-headers
    fi
    if [ "${libc_startfiles}" = "y" ]; then
        CT_DoLog EXTRA "Building C library start files"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" \
            obj/crt/crt1.o obj/crt/crti.o obj/crt/crtn.o
        CT_DoLog EXTRA "Installing C library start files"
        CT_DoExecLog ALL cp -av obj/crt/crt*.o "${CT_SYSROOT_DIR}/usr/lib"
        CT_DoExecLog ALL ${CT_TARGET}-gcc -nostdlib \
            -nostartfiles -shared -x c /dev/null -o "${CT_SYSROOT_DIR}/usr/lib/libc.so"
    fi
    if [ "${libc_full}" = "y" ]; then
        CT_DoLog EXTRA "Building C library"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS}

        CT_DoLog EXTRA "Installing C library"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" install
    fi

    CT_EndStep
}
