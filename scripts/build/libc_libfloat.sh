# This file adds functions to build libfloat
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

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
