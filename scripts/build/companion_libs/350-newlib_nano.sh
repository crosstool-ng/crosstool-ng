# This file adds functions to build the Newlib library using the 'nano' configuration
# Copyright © 2021 Keith Packard
# Licensed under the GPL v2 or later. See COPYING in the root of this package
#
# Edited by Keith Packard <keithp@keithp.com>
#

do_newlib_nano_get() { :; }
do_newlib_nano_extract() { :; }
do_newlib_nano_for_build() { :; }
do_newlib_nano_for_host() { :; }
do_newlib_nano_for_target() { :; }

if [ "${CT_COMP_LIBS_NEWLIB_NANO}" = "y" ]; then

# Download newlib_nano
do_newlib_nano_get() {
    CT_Fetch NEWLIB_NANO
}

do_newlib_nano_extract() {
    CT_ExtractPatch NEWLIB_NANO
}

#------------------------------------------------------------------------------
# Build an additional target libstdc++ with "-Os" (optimise for speed) option
# flag for libstdc++ "newlib_nano" variant.
do_cc_libstdcxx_newlib_nano()
{
    local -a final_opts
    local final_backend

    if [ "${CT_NEWLIB_NANO_GCC_LIBSTDCXX}" = "y" ]; then
        final_opts+=( "host=${CT_HOST}" )
	final_opts+=( "libstdcxx_name=newlib-nano" )
        final_opts+=( "prefix=${CT_PREFIX_DIR}" )
        final_opts+=( "complibs=${CT_HOST_COMPLIBS_DIR}" )
        final_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
        final_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
        final_opts+=( "lang_list=c,c++" )
        final_opts+=( "build_step=libstdcxx" )
	if [ "${CT_LIBC_NEWLIB_NANO_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
	    final_opts+=( "enable_optspace=yes" )
	fi

        if [ "${CT_BARE_METAL}" = "y" ]; then
            final_opts+=( "mode=baremetal" )
            final_opts+=( "build_libgcc=yes" )
            final_opts+=( "build_libstdcxx=yes" )
            final_opts+=( "build_libgfortran=yes" )
            if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
                final_opts+=( "build_staticlinked=yes" )
            fi
            final_backend=do_gcc_core_backend
        else
            final_backend=do_gcc_backend
        fi

        CT_DoStep INFO "Installing libstdc++ newlib-nano"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-libstdcxx-newlib-nano"
        "${final_backend}" "${final_opts[@]}"
        CT_Popd

        CT_EndStep
    fi
}

do_newlib_nano_for_target() {
    local -a newlib_nano_opts
    local cflags_for_target

    CT_DoStep INFO "Installing Newlib Nano library"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-newlib_nano-build-${CT_BUILD}"

    CT_DoLog EXTRA "Configuring Newlib Nano library"

    # Multilib is the default, so if it is not enabled, disable it.
    if [ "${CT_MULTILIB}" != "y" ]; then
        newlib_nano_opts+=("-Dmultilib=false")
    fi

    if [ "${CT_LIBC_NEWLIB_NANO_IO_FLOAT}" = "y" ]; then
        newlib_opts+=( "--enable-newlib-io-float" )
        if [ "${CT_LIBC_NEWLIB_NANO_IO_LDBL}" = "y" ]; then
            newlib_opts+=( "--enable-newlib-io-long-double" )
        else
            newlib_opts+=( "--disable-newlib-io-long-double" )
        fi
    else
        newlib_opts+=( "--disable-newlib-io-float" )
        newlib_opts+=( "--disable-newlib-io-long-double" )
    fi

    if [ "${CT_LIBC_NEWLIB_NANO_DISABLE_SUPPLIED_SYSCALLS}" = "y" ]; then
        newlib_opts+=( "--disable-newlib-supplied-syscalls" )
    else
        newlib_opts+=( "--enable-newlib-supplied-syscalls" )
    fi

    yn_args="IO_POS_ARGS:newlib-io-pos-args
IO_C99FMT:newlib-io-c99-formats
IO_LL:newlib-io-long-long
REGISTER_FINI:newlib-register-fini
NANO_MALLOC:newlib-nano-malloc
NANO_FORMATTED_IO:newlib-nano-formatted-io
ATEXIT_DYNAMIC_ALLOC:newlib-atexit-dynamic-alloc
GLOBAL_ATEXIT:newlib-global-atexit
LITE_EXIT:lite-exit
REENT_SMALL:newlib-reent-small
MULTITHREAD:newlib-multithread
RETARGETABLE_LOCKING:newlib-retargetable-locking
WIDE_ORIENT:newlib-wide-orient
FSEEK_OPTIMIZATION:newlib-fseek-optimization
FVWRITE_IN_STREAMIO:newlib-fvwrite-in-streamio
UNBUF_STREAM_OPT:newlib-unbuf-stream-opt
ENABLE_TARGET_OPTSPACE:target-optspace
    "

    for ynarg in $yn_args; do
        var="CT_LIBC_NEWLIB_NANO_${ynarg%:*}"
        eval var=\$${var}
        argument=${ynarg#*:}


        if [ "${var}" = "y" ]; then
            newlib_opts+=( "--enable-$argument" )
        else
            newlib_opts+=( "--disable-$argument" )
        fi
    done

    [ "${CT_LIBC_NEWLIB_NANO_EXTRA_SECTIONS}" = "y" ] && \
        CT_LIBC_NEWLIB_NANO_TARGET_CFLAGS="${CT_LIBC_NEWLIB_NANO_TARGET_CFLAGS} -ffunction-sections -fdata-sections"

    [ "${CT_LIBC_NEWLIB_NANO_LTO}" = "y" ] && \
        CT_LIBC_NEWLIB_NANO_TARGET_CFLAGS="${CT_LIBC_NEWLIB_NANO_TARGET_CFLAGS} -flto"

    cflags_for_target="${CT_ALL_TARGET_CFLAGS} ${CT_LIBC_NEWLIB_NANO_TARGET_CFLAGS}"

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
    "${CT_SRC_DIR}/newlib-nano/configure"                          \
        --host=${CT_BUILD}                                         \
        --target=${CT_TARGET}                                      \
        --prefix=${CT_PREFIX_DIR}                                  \
	--exec-prefix=${CT_PREFIX_DIR}/newlib-nano                 \
	--libdir=${CT_PREFIX_DIR}/newlib-nano/${CT_TARGET}/lib     \
        "${newlib_opts[@]}"                                        \
        "${CT_LIBC_NEWLIB_NANO_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building Newlib Nano C library"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    CT_DoLog EXTRA "Installing Newlib Nano C library"
    CT_DoExecLog ALL make install

    cat > "${CT_SYSROOT_DIR}/lib/nano.specs" <<EOF
%rename link	newlib_nano_link
%rename cpp	newlib_nano_cpp
%rename cc1plus	newlib_nano_cc1plus

*cpp:
-isystem ${CT_PREFIX_DIR}/newlib-nano/${CT_TARGET}/include %(newlib_nano_cpp)

*cc1plus:
-idirafter ${CT_PREFIX_DIR}/newlib-nano/${CT_TARGET}/include %(newlib_nano_cc1plus)  

*link:
-L${CT_PREFIX_DIR}/newlib-nano/${CT_TARGET}/lib/%M -L${CT_PREFIX_DIR}/newlib-nano/${CT_TARGET}/lib

EOF

    CT_Popd
    CT_EndStep

    do_cc_libstdcxx_newlib_nano
}

fi
