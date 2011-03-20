# This file adds the functions to build the GMP library
# Copyright 2008 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_gmp_get() { :; }
do_gmp_extract() { :; }
do_gmp() { :; }

# Overide functions depending on configuration
if [ "${CT_GMP}" = "y" ]; then

# Download GMP
do_gmp_get() {
    CT_GetFile "gmp-${CT_GMP_VERSION}" {ftp,http}://{ftp.sunet.se/pub,ftp.gnu.org}/gnu/gmp
}

# Extract GMP
do_gmp_extract() {
    CT_Extract "gmp-${CT_GMP_VERSION}"
    CT_Patch "gmp" "${CT_GMP_VERSION}"
}

do_gmp() {
    local -a gmp_opts

    mkdir -p "${CT_BUILD_DIR}/build-gmp"
    cd "${CT_BUILD_DIR}/build-gmp"

    CT_DoStep INFO "Installing GMP"

    CT_DoLog EXTRA "Configuring GMP"

    if [ "${CT_COMPLIBS_SHARED}" = "y" ]; then
        gmp_opts+=( --enable-shared --disable-static )
    else
        gmp_opts+=( --disable-shared --enable-static )
    fi

    CT_DoExecLog CFG                                \
    CFLAGS="${CT_CFLAGS_FOR_HOST} -fexceptions"     \
    "${CT_SRC_DIR}/gmp-${CT_GMP_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --prefix="${CT_COMPLIBS_DIR}"               \
        --enable-fft                                \
        --enable-mpbsd                              \
        --enable-cxx                                \
        "${gmp_opts[@]}"

    CT_DoLog EXTRA "Building GMP"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking GMP"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing GMP"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_GMP
