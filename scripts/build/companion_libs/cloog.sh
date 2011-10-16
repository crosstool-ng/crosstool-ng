# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog() { :; }

# Overide functions depending on configuration
if [ "${CT_CLOOG}" = "y" ]; then

# Download CLooG
do_cloog_get() {
    CT_GetFile "cloog-ppl-${CT_CLOOG_VERSION}"  \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract CLooG
do_cloog_extract() {
    local _t

    # Version 0.15.3 has a dirname 'cloog-ppl' (with no version in it!)
    # while versions 0.15.4 onward do have the version in the dirname.
    # But, because the infrastructure properly creates the extracted
    # directories (with tar's --strip-components), we can live safely...
    CT_Extract "cloog-ppl-${CT_CLOOG_VERSION}"
    CT_Patch "cloog-ppl" "${CT_CLOOG_VERSION}"

    if [ "${CT_CLOOG_NEEDS_AUTORECONF}" = "y" ]; then
        CT_Pushd "${CT_SRC_DIR}/cloog-ppl-${CT_CLOOG_VERSION}"
        CT_DoExecLog CFG ./autogen.sh
        CT_Popd
    fi
}

do_cloog() {
    local cloog_src_dir="${CT_SRC_DIR}/cloog-ppl-${CT_CLOOG_VERSION}"

    mkdir -p "${CT_BUILD_DIR}/build-cloog-ppl"
    cd "${CT_BUILD_DIR}/build-cloog-ppl"

    CT_DoStep INFO "Installing CLooG/ppl"

    CT_DoLog EXTRA "Configuring CLooG/ppl"

    CT_DoExecLog CFG                            \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"              \
    LDFLAGS="-lm"                               \
    "${cloog_src_dir}/configure"                \
        --build=${CT_BUILD}                     \
        --host=${CT_HOST}                       \
        --prefix="${CT_COMPLIBS_DIR}"           \
        --with-gmp="${CT_COMPLIBS_DIR}"         \
        --with-ppl="${CT_COMPLIBS_DIR}"         \
        --with-bits=gmp                         \
        --with-host-libstdcxx='-lstdc++'        \
        --disable-shared                        \
        --enable-static

    CT_DoLog EXTRA "Building CLooG/ppl"
    CT_DoExecLog ALL make ${JOBSFLAGS} libcloog.la

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG/ppl"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG/ppl"
    CT_DoExecLog ALL make install-libLTLIBRARIES install-pkgincludeHEADERS

    CT_EndStep
}

fi # CT_CLOOG
