# This file adds functions to build the musl C library
# Copyright 2013 Timo TerÃ¤s
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    local libc_src

    libc_src="http://www.musl-libc.org/releases"

    if [ "${CT_LIBC_MUSL_CUSTOM}" = "y" ]; then
        CT_GetCustom "musl" "${CT_LIBC_VERSION}"      \
                     "${CT_LIBC_MUSL_CUSTOM_LOCATION}"
    else # ! custom location
        CT_GetFile "musl-${CT_LIBC_VERSION}" "${libc_src}"
    fi # ! custom location
}

do_libc_extract() {
    # If using custom directory location, nothing to do.
    if [ "${CT_LIBC_MUSL_CUSTOM}" = "y" ]; then
        # Abort if the custom directory is not found.
        if ! [ -d "${CT_SRC_DIR}/musl-${CT_LIBC_VERSION}" ]; then
            CT_Abort "Directory not found: ${CT_SRC_DIR}/musl-${CT_LIBC_VERSION}"
        fi

        return 0
    fi

    CT_Extract "musl-${CT_LIBC_VERSION}"
    CT_Patch "musl" "${CT_LIBC_VERSION}"
}

do_libc_check_config() {
    :
}

do_libc_configure() {
    CT_DoLog EXTRA "Configuring C library"
    local -a extra_cflags
    local -a extra_config

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

    # NOTE: musl handles the build/host/target a little bit differently
    # then one would expect:
    #   build   : not used
    #   host    : the machine building musl
    #   target  : the machine musl runs on
    CT_DoExecLog CFG                \
    CFLAGS="${extra_cflags[@]}"     \
    CROSS_COMPILE="${CT_TARGET}-"   \
    ./configure                     \
        --host="${CT_TARGET}"       \
        --target="${CT_TARGET}"     \
        --prefix="/usr"             \
        --disable-gcc-wrapper       \
        "${extra_config[@]}"
}

do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers"

    # Simply copy files until musl has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build directory"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/musl-${CT_LIBC_VERSION}" \
                            "${CT_BUILD_DIR}/build-libc-headers"
    cd "${CT_BUILD_DIR}/build-libc-headers"

    do_libc_configure

    CT_DoLog EXTRA "Installing headers"
    CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" install-headers

    CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" \
        crt/crt1.o crt/crti.o crt/crtn.o
    CT_DoExecLog ALL cp -av crt/crt*.o "${CT_SYSROOT_DIR}/usr/lib"
    CT_DoExecLog ALL ${CT_TARGET}-gcc -nostdlib \
        -nostartfiles -shared -x c /dev/null -o "${CT_SYSROOT_DIR}/usr/lib/libc.so"
    CT_EndStep
}

do_libc() {
    CT_DoStep INFO "Installing C library"

    # Simply copy files until musl has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build directory"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/musl-${CT_LIBC_VERSION}" \
                            "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    do_libc_configure

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" install

    CT_EndStep
}

do_libc_post_cc() {
    :
}
