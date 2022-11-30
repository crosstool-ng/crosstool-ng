# This file adds functions to use the Picolibc library as the system libc
# Copyright © 2022 Joakim Nohlgård
# Licensed under the GPL v2 or later. See COPYING in the root of this package

picolibc_get()
{
    CT_Fetch PICOLIBC
}

picolibc_extract()
{
    CT_ExtractPatch PICOLIBC
}

picolibc_headers()
{
    CT_DoStep INFO "Installing C library headers"
    CT_DoExecLog ALL cp -a "${CT_SRC_DIR}/picolibc/newlib/libc/include/." "${CT_HEADERS_DIR}"
    CT_EndStep
}

picolibc_main()
{
    CT_DoStep INFO "Installing C library"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc"
    do_picolibc_common_install
    CT_Popd
    CT_EndStep
}
