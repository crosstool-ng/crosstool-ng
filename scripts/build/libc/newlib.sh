# This file adds functions to build the Newlib C library
# Copyright 2009 DoréDevelopment
# Licensed under the GPL v2. See COPYING in the root of this package
#
# Edited by Martin Lund <mgl@doredevelopment.dk>
#

do_libc_get() {
    local libc_src="{http://mirrors.kernel.org/sourceware/newlib,
                     ftp://sourceware.org/pub/newlib}"

    if [ "${CT_LIBC_NEWLIB_CUSTOM}" = "y" ]; then
        CT_GetCustom "newlib" "${CT_LIBC_NEWLIB_CUSTOM_VERSION}" \
            "${CT_LIBC_NEWLIB_CUSTOM_LOCATION}"
    else # ! custom location
        case "${CT_LIBC_VERSION}" in
            linaro-*)
                CT_GetLinaro "newlib" "${CT_LIBC_VERSION}"
                ;;
            *)
                # kernel.org mirror is outdated, keep last as a fallback
                CT_GetFile "newlib-${CT_LIBC_VERSION}" \
                           ftp://sourceware.org/pub/newlib \
                           http://mirrors.kernel.org/sourceware/newlib \
                           http://mirrors.kernel.org/sources.redhat.com/newlib
                ;;
        esac
    fi # ! custom location
}

do_libc_extract() {
    CT_Extract "newlib-${CT_LIBC_VERSION}"
    CT_Patch "newlib" "${CT_LIBC_VERSION}"

    if [ -n "${CT_ARCH_XTENSA_CUSTOM_NAME}" ]; then
        CT_ConfigureXtensa "newlib" "${CT_LIBC_VERSION}"
    fi
}

do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers & start files"
    CT_DoExecLog ALL cp -a "${CT_SRC_DIR}/newlib-${CT_LIBC_VERSION}/newlib/libc/include/." \
    "${CT_HEADERS_DIR}"
    if [ "${CT_ARCH_xtensa}" = "y" ]; then
        CT_DoLog EXTRA "Installing Xtensa headers"
        CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/newlib-${CT_LIBC_VERSION}/newlib/libc/sys/xtensa/include/."   \
                               "${CT_HEADERS_DIR}"
    fi
    CT_EndStep
}

do_libc() {
    local -a newlib_opts
    local cflags_for_target

    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Multilib is the default, so if it is not enabled, disable it.
    if [ "${CT_MULTILIB}" != "y" ]; then
        extra_config+=("--disable-multilib")
    fi

    if [ "${CT_LIBC_NEWLIB_IO_FLOAT}" = "y" ]; then
        newlib_opts+=( "--enable-newlib-io-float" )
        if [ "${CT_LIBC_NEWLIB_IO_LDBL}" = "y" ]; then
            newlib_opts+=( "--enable-newlib-io-long-double" )
        else
            newlib_opts+=( "--disable-newlib-io-long-double" )
        fi
    else
        newlib_opts+=( "--disable-newlib-io-float" )
        newlib_opts+=( "--disable-newlib-io-long-double" )
    fi

    if [ "${CT_LIBC_NEWLIB_DISABLE_SUPPLIED_SYSCALLS}" = "y" ]; then
        newlib_opts+=( "--disable-newlib-supplied-syscalls" )
    else
        newlib_opts+=( "--enable-newlib-supplied-syscalls" )
    fi

    yn_args="IO_POS_ARGS:newlib-io-pos-args
IO_C99FMT:newlib-io-c99-formats
IO_LL:newlib-io-long-long
NEWLIB_REGISTER_FINI:newlib-register-fini
NANO_MALLOC:newlib-nano-malloc
NANO_FORMATTED_IO:newlib-nano-formatted-io
ATEXIT_DYNAMIC_ALLOC:atexit-dynamic-alloc
GLOBAL_ATEXIT:newlib-global-atexit
LITE_EXIT:lite-exit
REENT_SMALL:reent-small
MULTITHREAD:multithread
WIDE_ORIENT:newlib-wide-orient
UNBUF_STREAM_OPT:unbuf-stream-opt
ENABLE_TARGET_OPTSPACE:target-optspace
    "

    for ynarg in $yn_args; do
        var="CT_LIBC_NEWLIB_${ynarg%:*}"
        eval var=\$${var}
        argument=${ynarg#*:}


        if [ "${var}" = "y" ]; then
            newlib_opts+=( "--enable-$argument" )
        else
            newlib_opts+=( "--disable-$argument" )
        fi
    done

    [ "${CT_LIBC_NEWLIB_EXTRA_SECTIONS}" = "y" ] && \
        CT_LIBC_NEWLIB_TARGET_CFLAGS="${CT_LIBC_NEWLIB_TARGET_CFLAGS} -ffunction-sections -fdata-sections"

    [ "${CT_LIBC_NEWLIB_LTO}" = "y" ] && \
        CT_LIBC_NEWLIB_TARGET_CFLAGS="${CT_LIBC_NEWLIB_TARGET_CFLAGS} -flto"

    cflags_for_target="${CT_TARGET_CFLAGS} ${CT_LIBC_NEWLIB_TARGET_CFLAGS}"

    # Note: newlib handles the build/host/target a little bit differently
    # than one would expect:
    #   build  : not used
    #   host   : the machine building newlib
    #   target : the machine newlib runs on
    CT_DoExecLog CFG                                               \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                                 \
    CFLAGS_FOR_TARGET="${cflags_for_target}"                       \
    AR_FOR_TARGET="`which ${CT_TARGET}-gcc-ar`"                    \
    RANLIB_FOR_TARGET="`which ${CT_TARGET}-gcc-ranlib`"            \
    "${CT_SRC_DIR}/newlib-${CT_LIBC_VERSION}/configure"            \
        --host=${CT_BUILD}                                         \
        --target=${CT_TARGET}                                      \
        --prefix=${CT_PREFIX_DIR}                                  \
        "${newlib_opts[@]}"                                        \
        "${CT_LIBC_NEWLIB_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make install

    if [ "${CT_BUILD_MANUALS}" = "y" ]; then
        local -a doc_dir="${CT_BUILD_DIR}/build-libc/${CT_TARGET}"

        CT_DoLog EXTRA "Building and installing the C library manual"
        CT_DoExecLog ALL make pdf html

        # NEWLIB install-{pdf.html} fail for some versions
        CT_DoExecLog ALL mkdir -p "${CT_PREFIX_DIR}/share/doc/newlib"
        CT_DoExecLog ALL cp -av "${doc_dir}/newlib/libc/libc.pdf"   \
                                "${doc_dir}/newlib/libm/libm.pdf"   \
                                "${doc_dir}/newlib/libc/libc.html"  \
                                "${doc_dir}/newlib/libm/libm.html"  \
                                "${CT_PREFIX_DIR}/share/doc/newlib"
    fi

    CT_EndStep
}

do_libc_post_cc() {
    :
}
