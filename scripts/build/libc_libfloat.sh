# This file adds functions to build libfloat
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Define libfloat functions depending on wether it is selected or not
if [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ]; then

# Download libfloat
do_libfloat_get() {
    # Please note: because the file we download, and the file we store on the
    # file system don't have the same name, CT_GetFile will always try to
    # download the file over and over.
    # To avoid this, we check that the file we want already exists in the
    # tarball directory first. This is an ugly hack that overrides the standard
    # CT_GetFile behavior... Sight...
    lib_float_url="ftp://ftp.de.debian.org/debian/pool/main/libf/libfloat/"
    ext=`CT_GetFileExtension "${CT_LIBFLOAT_FILE}"`
    if [ -z "${ext}" ]; then
        CT_GetFile libfloat_990616.orig "${lib_float_url}"
        ext=`CT_GetFileExtension "libfloat_990616.orig"`
        # Hack: remove the .orig extension, and change _ to -
        mv -v "${CT_TARBALLS_DIR}/libfloat_990616.orig${ext}" \
              "${CT_TARBALLS_DIR}/libfloat-990616${ext}"      2>&1 |CT_DoLog DEBUG
    fi
}

# Extract libfloat
do_libfloat_extract() {
    [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ] && CT_ExtractAndPatch "${CT_LIBFLOAT_FILE}"
}

# Build libfloat
do_libfloat() {
    # Here we build and install libfloat for the target, so that the C library
    # builds OK with those versions of gcc that have severed softfloat support
    # code
    [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ] || return 0
	CT_DoStep INFO "Installing software floating point emulation library libfloat"

    CT_Pushd "${CT_BUILD_DIR}"
    CT_DoLog EXTRA "Copying sources to build dir"
    mkdir build-libfloat
    cd build-libfloat
    ( cd "${CT_SRC_DIR}/${CT_LIBFLOAT_FILE}"; tar cf - . ) |tar xvf - |CT_DoLog DEBUG

    CT_DoLog EXTRA "Cleaning library"
    make clean 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Building library"
    make CROSS_COMPILE="${CT_CC_CORE_PREFIX_DIR}/bin/${CT_TARGET}-" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Installing library"
    make CROSS_COMPILE="${CT_CC_CORE_PREFIX_DIR}/bin/${CT_TARGET}-" \
         DESTDIR="${CT_SYSROOT_DIR}" install                       2>&1 |CT_DoLog DEBUG

    CT_Popd

    CT_EndStep
}

else # "${CT_ARCH_FLOAT_SW_LIBFLOAT}" != "y"

do_libfloat_get() {
    true
}
do_libfloat_extract() {
    true
}
do_libfloat() {
    true
}

fi
