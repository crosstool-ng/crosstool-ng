# This file adds functions to build libfloat
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Define libfloat functions depending on wether it is selected or not
if [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ]; then

# Download libfloat
do_libfloat_get() {
    # Ah! libfloat separates the version string from the base name with
    # an underscore. We need to workaround this in a sane manner: soft link.
    local libfloat_file=`echo "${CT_LIBFLOAT_FILE}" |sed -r -e 's/^libfloat-/libfloat_/;'`
    CT_GetFile "${libfloat_file}"                                    \
               ftp://ftp.de.debian.org/debian/pool/main/libf/libfloat
    CT_Pushd "${CT_TARBALLS_DIR}"
    ext=`CT_GetFileExtension "${libfloat_file}"`
    ln -svf "${libfloat_file}${ext}" "${CT_LIBFLOAT_FILE}${ext}" |CT_DoLog DEBUG
    CT_Popd
}

# Extract libfloat
do_libfloat_extract() {
    CT_ExtractAndPatch "${CT_LIBFLOAT_FILE}"
}

# Build libfloat
do_libfloat() {
    # Here we build and install libfloat for the target, so that the C library
    # builds OK with those versions of gcc that have severed softfloat support
    # code
    CT_DoStep INFO "Installing software floating point emulation library libfloat"
    CT_Pushd "${CT_BUILD_DIR}"
    mkdir -p build-libfloat
    cd build-libfloat

    CT_DoLog EXTRA "Copying sources to build dir"
    ( cd "${CT_SRC_DIR}/${CT_LIBFLOAT_FILE}"; tar cf - . ) |tar xvf - |CT_DoLog ALL

    CT_DoLog EXTRA "Cleaning library"
    make clean 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Building library"
    make CROSS_COMPILE="${CT_TARGET}-" 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing library"
    make DESTDIR="${CT_SYSROOT_DIR}" install    2>&1 |CT_DoLog ALL

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
