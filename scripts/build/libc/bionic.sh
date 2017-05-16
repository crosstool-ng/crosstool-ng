# This file adds functions to extract the bionic C library from the Android NDK
# Copyright 2017 Howard Chu
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    if [ "${CT_LIBC_BIONIC_CUSTOM}" = "y" ]; then
        CT_GetCustom "bionic" "${CT_LIBC_BIONIC_CUSTOM_VERSION}" \
            "${CT_LIBC_BIONIC_CUSTOM_LOCATION}"
    else # ! custom location
        CT_GetFile "android-ndk-${CT_LIBC_VERSION}-linux-x86_64.zip" https://dl.google.com/android/repository
    fi # ! custom location
}

do_libc_extract() {
    CT_Extract "android-ndk-${CT_LIBC_VERSION}-linux-x86_64"
    CT_Pushd "${CT_SRC_DIR}/android-ndk-${CT_LIBC_VERSION}/"
    CT_Patch nochdir bionic "${CT_LIBC_VERSION}"
    CT_Popd
}

# Install Unified headers
do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers"
    CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/android-ndk-${CT_LIBC_VERSION}/sysroot/usr" "${CT_SYSROOT_DIR}"
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
    CT_DoExecLog ALL cp -r "${CT_SRC_DIR}/android-ndk-${CT_LIBC_VERSION}/platforms/android-${CT_ANDROID_API}/arch-${arch}/usr" "${CT_SYSROOT_DIR}"
    CT_EnvModify CT_TARGET_CFLAGS "${CT_TARGET_CFLAGS} -D__ANDROID_API__=${CT_ANDROID_API}"
}

do_libc_post_cc() {
    :
}

