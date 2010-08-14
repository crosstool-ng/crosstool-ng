# This file declares functions to install the kernel headers for mingw
# Copyright 2009 Bart vdr. Meulen
# Licensed under the GPL v2. See COPYING in the root of this package

CT_DoKernelTupleValues() {
    CT_TARGET_KERNEL="mingw32"
    CT_TARGET_SYS=
}

do_kernel_get() {
    CT_GetFile "w32api-${CT_W32API_VERSION}-mingw32-src" \
        http://downloads.sourceforge.net/sourceforge/mingw
}

do_kernel_extract() {
    CT_Extract "w32api-${CT_W32API_VERSION}-mingw32-src"
}

do_kernel_headers() {
    CT_DoStep INFO "Installing kernel headers"

    mkdir -p "${CT_HEADERS_DIR}"
    cp -r ${CT_SRC_DIR}/w32api-${CT_W32API_VERSION}-mingw32/include/* \
          ${CT_HEADERS_DIR}

    CT_EndStep
}
