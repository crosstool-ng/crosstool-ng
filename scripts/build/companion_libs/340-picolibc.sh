# This file adds functions to build the Picolibc library
# Copyright © 2020 Keith Packard
# Licensed under the GPL v2 or later. See COPYING in the root of this package
#
# Edited by Keith Packard <keithp@keithp.com>
#

do_picolibc_get() { :; }
do_picolibc_extract() { :; }
do_picolibc_for_build() { :; }
do_picolibc_for_host() { :; }
do_picolibc_for_target() { :; }

if [ "${CT_LIBC_PICOLIBC}" = "y" -o "${CT_COMP_LIBS_PICOLIBC}" = "y" ]; then

do_picolibc_common_install() {
    local -a picolibc_opts
    local cflags_for_target

    CT_DoLog EXTRA "Configuring C library"

    # Multilib is the default, so if it is not enabled, disable it.
    if [ "${CT_MULTILIB}" != "y" ]; then
        picolibc_opts+=("-Dmultilib=false")
    fi

    yn_args="IO_C99FMT:io-c99-formats
IO_LL:io-long-long
REGISTER_FINI:newlib-register-fini
NANO_MALLOC:newlib-nano-malloc
ATEXIT_DYNAMIC_ALLOC:newlib-atexit-dynamic-alloc
GLOBAL_ATEXIT:newlib-global-atexit
LITE_EXIT:lite-exit
MULTITHREAD:newlib-multithread
RETARGETABLE_LOCKING:newlib-retargetable-locking
    "

    for ynarg in $yn_args; do
        var="CT_LIBC_PICOLIBC_${ynarg%:*}"
        eval var=\$${var}
        argument=${ynarg#*:}


        if [ "${var}" = "y" ]; then
            picolibc_opts+=( "-D$argument=true" )
        else
            picolibc_opts+=( "-D$argument=false" )
        fi
    done

    [ "${CT_LIBC_PICOLIBC_EXTRA_SECTIONS}" = "y" ] && \
        CT_LIBC_PICOLIBC_TARGET_CFLAGS="${CT_LIBC_PICOLIBC_TARGET_CFLAGS} -ffunction-sections -fdata-sections"

    [ "${CT_LIBC_PICOLIBC_LTO}" = "y" ] && \
        CT_LIBC_PICOLIBC_TARGET_CFLAGS="${CT_LIBC_PICOLIBC_TARGET_CFLAGS} -flto"

    cflags_for_target="${CT_ALL_TARGET_CFLAGS} ${CT_LIBC_PICOLIBC_TARGET_CFLAGS}"

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
endian = '${CT_ARCH_ENDIAN}'

[properties]
c_args = [ ${meson_cflags} '-nostdlib', '-fno-common', '-ftls-model=local-exec' ]
needs_exe_wrapper = true
skip_sanity_check = true
default_flash_addr = '${CT_LIBC_PICOLIBC_DEFAULT_FLASH_ADDR}'
default_flash_size = '${CT_LIBC_PICOLIBC_DEFAULT_FLASH_SIZE}'
default_ram_addr = '${CT_LIBC_PICOLIBC_DEFAULT_RAM_ADDR}'
default_ram_size = '${CT_LIBC_PICOLIBC_DEFAULT_RAM_SIZE}'
EOF

    local picolibc_sysroot_dir
    local picolibc_lib_dir
    if [ "${CT_LIBC_PICOLIBC}" = 'y' ]; then
        picolibc_sysroot_dir="${CT_SYSROOT_DIR}"
        picolibc_lib_dir="${CT_SYSROOT_DIR}/lib"
        picolibc_opts+=( '-Dsystem-libc=true' )
    else
        picolibc_sysroot_dir="${CT_PREFIX_DIR}/picolibc"
        picolibc_lib_dir="${picolibc_sysroot_dir}/${CT_TARGET}/lib"
    fi

    CT_DoExecLog CFG                                               \
    meson                                                          \
        --cross-file picolibc-cross.txt                            \
        --prefix="${picolibc_sysroot_dir}"                         \
        -Dincludedir=include                                       \
        -Dlibdir="${picolibc_lib_dir}"                             \
        -Dspecsdir="${CT_SYSROOT_DIR}/lib"                         \
        "${CT_SRC_DIR}/picolibc"                                   \
        "${picolibc_opts[@]}"                                      \
        "${CT_LIBC_PICOLIBC_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL ninja

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL ninja install
}

fi # CT_LIBC_PICOLIBC -o CT_COMP_LIBS_PICOLIBC

if [ "${CT_COMP_LIBS_PICOLIBC}" = "y" ]; then

do_cc_libstdcxx_picolibc() { :; }

# Download picolibc
do_picolibc_get() {
    CT_Fetch PICOLIBC
}

do_picolibc_extract() {
    CT_ExtractPatch PICOLIBC
}

if [ "${CT_LIBC_PICOLIBC_GCC_LIBSTDCXX}" = "y" ]; then
#------------------------------------------------------------------------------
# Build an additional target libstdc++ with "-Os" (optimise for speed) option
# flag for libstdc++ "picolibc" variant.
do_cc_libstdcxx_picolibc()
{
    local -a final_opts
    local final_backend

    final_opts+=( "host=${CT_HOST}" )
    final_opts+=( "libstdcxx_name=picolibc" )
    final_opts+=( "prefix=${CT_PREFIX_DIR}" )
    final_opts+=( "complibs=${CT_HOST_COMPLIBS_DIR}" )
    final_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    final_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    final_opts+=( "lang_list=c,c++" )
    final_opts+=( "build_step=libstdcxx" )
    final_opts+=( "extra_config+=('--enable-stdio=stdio_pure')" )
    if [ "${CT_PICOLIBC_older_than_1_8}" = "y" ]; then
	final_opts+=( "extra_config+=('--disable-wchar_t')" )
    fi
    if [ "${CT_LIBC_PICOLIBC_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
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

    CT_DoStep INFO "Installing libstdc++ picolibc"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-libstdcxx-picolibc"
    "${final_backend}" "${final_opts[@]}"
    CT_Popd

    CT_EndStep
}
fi # CT_LIBC_PICOLIBC_GCC_LIBSTDCXX

do_picolibc_for_target() {
    CT_DoStep INFO "Installing Picolibc library"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-picolibc-build-${CT_BUILD}"
    do_picolibc_common_install
    CT_Popd
    CT_EndStep
    do_cc_libstdcxx_picolibc
}

fi # CT_COMP_LIBS_PICOLIBC
