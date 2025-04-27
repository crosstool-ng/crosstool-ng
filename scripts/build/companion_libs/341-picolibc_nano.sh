# Copyright (c) 2025, Synopsys, Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3) Neither the name of the Synopsys, Inc., nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

do_picolibc_nano_get() { :; }
do_picolibc_nano_extract() { :; }
do_picolibc_nano_for_build() { :; }
do_picolibc_nano_for_host() { :; }
do_picolibc_nano_for_target() { :; }

if [ "${CT_COMP_LIBS_PICOLIBC_NANO}" = "y" ]; then

# Download picolibc
do_picolibc_nano_get() {
    CT_Fetch PICOLIBC_NANO
}

do_picolibc_nano_extract() {
    CT_ExtractPatch PICOLIBC_NANO
}

#------------------------------------------------------------------------------
# Build an additional target libstdc++ with "-Os" (optimize for speed) option
# flag for libstdc++ "picolibc" variant.
do_cc_libstdcxx_picolibc_nano()
{
    local -a final_opts
    local final_backend

    if [ "${CT_LIBC_PICOLIBC_NANO_GCC_LIBSTDCXX}" = "y" ]; then
        final_opts+=( "host=${CT_HOST}" )
        final_opts+=( "libstdcxx_name=picolibc-nano" )
        final_opts+=( "prefix=${CT_PREFIX_DIR}" )
        final_opts+=( "complibs=${CT_HOST_COMPLIBS_DIR}" )
        final_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
        final_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
        final_opts+=( "lang_list=c,c++" )
        final_opts+=( "build_step=libstdcxx" )
        final_opts+=( "extra_config+=('--enable-stdio=stdio_pure')" )
        final_opts+=( "extra_config+=('--with-headers=${CT_PREFIX_DIR}/picolibc-nano/include')" )
        if [ "${CT_PICOLIBC_NANO_older_than_1_8}" = "y" ]; then
            final_opts+=( "extra_config+=('--disable-wchar_t')" )
        fi
        if [ "${CT_LIBC_PICOLIBC_NANO_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
            final_opts+=( "enable_optspace=yes" )
        fi
        if [ -n "${CT_LIBC_PICOLIBC_NANO_GCC_LIBSTDCXX_TARGET_CXXFLAGS}" ]; then
            final_opts+=( "extra_cxxflags_for_target=${CT_LIBC_PICOLIBC_NANO_GCC_LIBSTDCXX_TARGET_CXXFLAGS}" )
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

        CT_DoStep INFO "Installing libstdc++ for Picolibc Nano"
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-libstdcxx-picolibc-nano"
        "${final_backend}" "${final_opts[@]}"
        CT_Popd

        CT_EndStep
    fi
}

do_picolibc_nano_for_target() {
    local -a picolibc_nano_opts
    local cflags_for_target

    CT_DoStep INFO "Installing Picolibc Nano library"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-picolibc-nano-build-${CT_BUILD}"

    CT_DoLog EXTRA "Configuring Picolibc Nano library"

    # Multilib is the default, so if it is not enabled, disable it.
    if [ "${CT_MULTILIB}" != "y" ]; then
        picolibc_nano_opts+=("-Dmultilib=false")
    fi

    yn_args="IO_C99FMT:io-c99-formats
IO_LL:io-long-long
REGISTER_FINI:newlib-register-fini
NANO_MALLOC:newlib-nano-malloc
ATEXIT_DYNAMIC_ALLOC:newlib-atexit-dynamic-alloc
GLOBAL_ATEXIT:newlib-global-atexit
SINGLE_THREAD:single-thread
    "

    for ynarg in $yn_args; do
        var="CT_LIBC_PICOLIBC_NANO_${ynarg%:*}"
        eval var=\$${var}
        argument=${ynarg#*:}


        if [ "${var}" = "y" ]; then
            picolibc_nano_opts+=( "-D$argument=true" )
        else
            picolibc_nano_opts+=( "-D$argument=false" )
        fi
    done

    [ "${CT_LIBC_PICOLIBC_NANO_EXTRA_SECTIONS}" = "y" ] && \
        CT_LIBC_PICOLIBC_NANO_TARGET_CFLAGS="${CT_LIBC_PICOLIBC_NANO_TARGET_CFLAGS} -ffunction-sections -fdata-sections"

    [ "${CT_LIBC_PICOLIBC_NANO_LTO}" = "y" ] && \
        CT_LIBC_PICOLIBC_NANO_TARGET_CFLAGS="${CT_LIBC_PICOLIBC_NANO_TARGET_CFLAGS} -flto"

    cflags_for_target="${CT_ALL_TARGET_CFLAGS} ${CT_LIBC_PICOLIBC_NANO_TARGET_CFLAGS}"

    # Note: picolibc handles the build/host/target a little bit differently
    # than one would expect:
    #   build  : not used
    #   host   : the machine building picolibc
    #   target : the machine picolibc runs on
    meson_cflags=""
    for cflag in ${cflags_for_target}; do
        meson_cflags="${meson_cflags} '${cflag}',"
    done
    cat << EOF > picolibc-cross.txt
[binaries]
c = '${CT_TARGET}-${CT_CC}'
ar = '${CT_TARGET}-ar'
as = '${CT_TARGET}-as'
strip = '${CT_TARGET}-strip'

[host_machine]
system = '${CT_TARGET_VENDOR}'
cpu_family = '${CT_TARGET_ARCH}'
cpu = '${CT_TARGET_ARCH}'
endian = 'little'

[properties]
c_args = [ ${meson_cflags} '-nostdlib', '-fno-common', '-ftls-model=local-exec' ]
needs_exe_wrapper = true
skip_sanity_check = true
default_flash_addr = '${CT_LIBC_PICOLIBC_DEFAULT_FLASH_ADDR}'
default_flash_size = '${CT_LIBC_PICOLIBC_DEFAULT_FLASH_SIZE}'
default_ram_addr = '${CT_LIBC_PICOLIBC_DEFAULT_RAM_ADDR}'
default_ram_size = '${CT_LIBC_PICOLIBC_DEFAULT_RAM_SIZE}'
EOF

    CT_DoExecLog CFG                                               \
    meson setup .                                                  \
        "${CT_SRC_DIR}/picolibc"                                   \
        --cross-file picolibc-cross.txt                            \
        --prefix="${CT_PREFIX_DIR}/picolibc-nano/${CT_TARGET}"     \
        -Dincludedir=include                                       \
        -Dlibdir="${CT_PREFIX_DIR}/picolibc-nano/${CT_TARGET}/lib" \
        -Dspecsdir=none                                            \
        "${picolibc_nano_opts[@]}"                                 \
        "${CT_LIBC_PICOLIBC_NANO_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${CT_LIBC_PICOLIBC_NANO_OBSOLETE_FLOAT}" = 'y' ]; then
        cat << EOF >> picolibc.h
#if (__riscv_flen < 64) && !defined(__riscv_zdinx)
#undef __OBSOLETE_MATH
#undef __OBSOLETE_MATH_FLOAT
#undef __OBSOLETE_MATH_DOUBLE
#define __OBSOLETE_MATH 1
#endif
EOF
    fi

    CT_DoLog EXTRA "Building Picolibc Nano library"
    CT_DoExecLog ALL ninja

    CT_DoLog EXTRA "Installing Picolibc Nano library"
    CT_DoExecLog ALL ninja install

    cat << EOF > "${CT_SYSROOT_DIR}/lib/nano.specs"
%rename link	picolibc_nano_link
%rename cpp	picolibc_nano_cpp
%rename cc1plus	picolibc_nano_cc1plus

*cpp:
-isystem %:getenv(GCC_EXEC_PREFIX ../../picolibc-nano/${CT_TARGET}/include) %(picolibc_nano_cpp)

*cc1plus:
-idirafter %:getenv(GCC_EXEC_PREFIX ../../picolibc-nano/${CT_TARGET}/include) %(picolibc_nano_cc1plus)

*link:
-L%:getenv(GCC_EXEC_PREFIX ../../picolibc-nano/${CT_TARGET}/lib/%M) -L%:getenv(GCC_EXEC_PREFIX ../../picolibc-nano/${CT_TARGET}/lib) %(picolibc_nano_link)
EOF

    CT_Popd
    CT_EndStep
    do_cc_libstdcxx_picolibc_nano
}

fi
