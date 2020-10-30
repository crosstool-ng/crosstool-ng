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

if [ "${CT_COMP_LIBS_PICOLIBC}" = "y" ]; then

# Download picolibc
do_picolibc_get() {
    CT_DoStep INFO "Downloading Picolibc library"
    CT_Fetch PICOLIBC
}

do_picolibc_extract() {
    CT_DoStep INFO "Extracting Picolibc library"
    CT_ExtractPatch PICOLIBC
}

do_picolibc_for_target() {
    local -a picolibc_opts
    local cflags_for_target

    CT_DoStep INFO "Installing Picolibc library"

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring Picolibc library"

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

    [ "${CT_USE_SYSROOT}" = "y" ] && \
	picolibc_opts+=( "-Dsysroot-install=true" )

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
c = '${CT_TARGET}-gcc'
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
EOF
    picolibc_prefix="${CT_SYSROOT_DIR}"
    if [ "${CT_USE_SYSROOT}" != "y" -a "${CT_LIBC_NONE}" != "y" ]; then
	picolibc_prefix="${picolibc_prefix}"/picolibc
    fi

    CT_DoExecLog CFG                                               \
    meson                                                          \
        --cross-file picolibc-cross.txt                            \
        --prefix="${picolibc_prefix}"                              \
	-Dspecsdir="${CT_SYSROOT_DIR}"/lib                         \
        "${CT_SRC_DIR}/picolibc"                                   \
        "${picolibc_opts[@]}"                                      \
        "${CT_LIBC_PICOLIBC_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL ninja

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL ninja install

    CT_Popd
    CT_EndStep
}

fi
