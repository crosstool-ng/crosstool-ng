# This file adds functions to build the Newlib C library
# Copyright 2009 DoréDevelopment
# Licensed under the GPL v2. See COPYING in the root of this package
#
# Edited by Martin Lund <mgl@doredevelopment.dk>
#

libc_newlib_version() {
    if [ -z "${CT_LIBC_NEWLIB_CVS}" ]; then
        echo "${CT_LIBC_VERSION}"
    else
        echo "cvs${CT_LIBC_VERSION:+-${CT_LIBC_VERSION}}"
    fi
}

do_libc_get() {
    local libc_src
    local avr32headers_src
    local save_chunks

    libc_src="ftp://sources.redhat.com/pub/newlib"
    avr32headers_src="http://dev.doredevelopment.dk/avr32-toolchain/sources"

    save_chunks="${CT_DOWNLOAD_MAX_CHUNKS}"
    CT_DOWNLOAD_MAX_CHUNKS=1

    if [ -z "${CT_LIBC_NEWLIB_CVS}" ]; then
        CT_GetFile "newlib-${CT_LIBC_VERSION}" ${libc_src}
    else
        CT_GetCVS "newlib-$(libc_newlib_version)"                   \
                  ":pserver:anoncvs@sources.redhat.com:/cvs/src"    \
                  "newlib"                                          \
                  "${CT_LIBC_VERSION}"                              \
                  "newlib-$(libc_newlib_version)=src"
    fi

    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_GetFile "avr32headers" ${avr32headers_src}
    fi

    CT_DOWNLOAD_MAX_CHUNKS="${save_chunks}"
}

do_libc_extract() {
    CT_Extract "newlib-$(libc_newlib_version)"
    CT_Patch "newlib" "$(libc_newlib_version)"

    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_Extract "avr32headers"
    fi
}

do_libc_check_config() {
    :
}

do_libc_headers() {
    :
}

do_libc_start_files() {
    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Note: newlib handles the build/host/target a little bit differently
    # than one would expect:
    #   build  : not used
    #   host   : the machine building newlib
    #   target : the machine newlib runs on
    CC_FOR_BUILD="${CT_BUILD}-gcc"                      \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS} -O"          \
    AR=${CT_TARGET}-ar                                  \
    RANLIB=${CT_TARGET}-ranlib                          \
    CT_DoExecLog CFG                                    \
    "${CT_SRC_DIR}/newlib-$(libc_newlib_version)/configure" \
        --host=${CT_BUILD}                              \
        --target=${CT_TARGET}                           \
        --prefix=${CT_PREFIX_DIR}

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make install install_root="${CT_SYSROOT_DIR}"

    CT_EndStep
}

do_libc() {
    :
}

do_libc_finish() {
    CT_DoStep INFO "Finishing C library"
    
    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_DoLog EXTRA "Installing Atmel's AVR32 headers"
        CT_DoExecLog ALL cp -r ${CT_SRC_DIR}/avr32headers "${CT_PREFIX_DIR}/${CT_TARGET}/include/avr32"
    fi

    CT_EndStep
}
