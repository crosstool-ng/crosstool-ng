# This file adds functions to build the Newlib C library
# Copyright 2009 DoréDevelopment
# Licensed under the GPL v2. See COPYING in the root of this package
#
# Edited by Martin Lund <mgl@doredevelopment.dk>
#

newlib_nano_movelibs()
{
    local multi_flags multi_dir multi_os_dir multi_os_dir_gcc multi_root multi_index multi_count

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libc.a" \
                        "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libc_nano.a"
    CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libg.a" \
                        "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libg_nano.a"
    if [ -f ${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/librdimon.a ]; then
        CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/librdimon.a" \
                            "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/librdimon_nano.a"
    fi
    if [ "${CT_CC_GCC_STATIC_LIBSTDCXX}" = "y" ]; then
        CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libstdc++.a" \
                            "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libstdc++_nano.a"
        CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libsupc++.a" \
                            "${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_dir}/libsupc++_nano.a"
    fi
}

newlib_start_files()
{
    CT_DoStep INFO "Installing C library headers & start files"
    CT_DoExecLog ALL cp -a "${CT_SRC_DIR}/newlib/newlib/libc/include/." \
    "${CT_HEADERS_DIR}"
    if [ "${CT_ARCH_XTENSA}" = "y" ]; then
        CT_DoLog EXTRA "Installing Xtensa headers"
        CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/newlib/newlib/libc/sys/xtensa/include/."   \
                               "${CT_HEADERS_DIR}"
    fi
    CT_EndStep
}

newlib_main()
{
    local -a newlib_opts
    local cflags_for_target

    CT_DoStep INFO "Installing C library"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Multilib is the default, so if it is not enabled, disable it.
    if [ "${CT_MULTILIB}" != "y" ]; then
        newlib_opts+=("--disable-multilib")
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
ATEXIT_DYNAMIC_ALLOC:newlib-atexit-dynamic-alloc
GLOBAL_ATEXIT:newlib-global-atexit
LITE_EXIT:lite-exit
REENT_SMALL:newlib-reent-small
MULTITHREAD:newlib-multithread
WIDE_ORIENT:newlib-wide-orient
UNBUF_STREAM_OPT:newlib-unbuf-stream-opt
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

    cflags_for_target="${CT_ALL_TARGET_CFLAGS} ${CT_LIBC_NEWLIB_TARGET_CFLAGS}"

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
    ${CONFIG_SHELL}                                                \
    "${CT_SRC_DIR}/newlib/configure"                               \
        --host=${CT_BUILD}                                         \
        --target=${CT_TARGET}                                      \
        --prefix=${CT_PREFIX_DIR}                                  \
        "${newlib_opts[@]}"                                        \
        "${CT_LIBC_NEWLIB_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

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

    CT_Popd
    CT_EndStep
}

newlib_post_cc()
{
    if [ "${CT_LIBC_NEWLIB_NANO_SPEC}" = "y" ]; then
        CT_DoLog EXTRA "Move files to match nano.spec layout"
        CT_IterateMultilibs newlib_nano_movelibs newlib_nano_libs

        CT_DoExecLog ALL mkdir -p "${CT_PREFIX_DIR}/${CT_TARGET}/include/newlib-nano"
        CT_DoExecLog ALL mv "${CT_PREFIX_DIR}/${CT_TARGET}/include/newlib.h" \
                            "${CT_PREFIX_DIR}/${CT_TARGET}/include/newlib-nano"
    fi
}
