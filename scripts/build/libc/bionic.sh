# This file adds functions to extract the bionic C library from the Android NDK
# Copyright 2017 Howard Chu
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    CT_Fetch ANDROID_NDK
}

do_libc_extract() {
    CT_ExtractPatch ANDROID_NDK
}

# Install Unified headers
do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers"
    CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/android-ndk/sysroot/usr" "${CT_SYSROOT_DIR}"
}

do_libc() {
    local arch="${CT_ARCH}"
    if [ "${CT_ARCH_64}" = "y" ]; then
        if [ "${CT_ARCH}" = "x86" ]; then
            arch="${arch}_"
        fi
        arch="${arch}64"
    fi
    CT_DoStep INFO "Installing C library binaries"
    CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/android-ndk/platforms/android-${CT_ANDROID_API}/arch-${arch}/usr" "${CT_SYSROOT_DIR}"
    CT_EnvModify CT_TARGET_CFLAGS "${CT_TARGET_CFLAGS} -D__ANDROID_API__=${CT_ANDROID_API}"
}

do_libc_post_cc() {
    :
}

