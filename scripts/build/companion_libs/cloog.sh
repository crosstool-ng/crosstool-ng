# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog() { :; }
do_cloog_target() { :; }

# Overide functions depending on configuration
if [ "${CT_PPL_CLOOG}" = "y" ]; then

# Download CLooG
do_cloog_get() {
    CT_GetFile "cloog-ppl-${CT_CLOOG_VERSION}"  \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract CLooG
do_cloog_extract() {
    CT_Extract "cloog-ppl-${CT_CLOOG_VERSION}"
    CT_Pushd "${CT_SRC_DIR}/cloog-ppl"
    CT_Patch "cloog-ppl-${CT_CLOOG_VERSION}" nochdir
    CT_Popd
}

do_cloog() {
    mkdir -p "${CT_BUILD_DIR}/build-cloog-ppl"
    cd "${CT_BUILD_DIR}/build-cloog-ppl"

    CT_DoStep INFO "Installing CLooG/ppl"

    CT_DoLog EXTRA "Configuring CLooG/ppl"
    CFLAGS="${CT_CFLAGS_FOR_HOST}"      \
    CT_DoExecLog ALL                    \
    "${CT_SRC_DIR}/cloog-ppl/configure" \
        --build=${CT_BUILD}             \
        --host=${CT_HOST}               \
        --prefix="${CT_PREFIX_DIR}"     \
        --with-gmp="${CT_PREFIX_DIR}"   \
        --with-ppl="${CT_PREFIX_DIR}"   \
        --disable-shared                \
        --enable-static                 \
        --with-bits=gmp

    CT_DoLog EXTRA "Building CLooG/ppl"
    CT_DoExecLog ALL make ${PARALLELMFLAGS}

    if [ "${CT_CLOOG_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG/ppl"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG/ppl"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_PPL_CLOOG
