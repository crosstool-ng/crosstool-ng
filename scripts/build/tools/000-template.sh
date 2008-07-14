# Template file for a tool utility

# Check here wether your tool is enabled or not.
# This will get redefined over and over again for each tool, so don't
# count on it in the functions below.
is_enabled="${CT_FOOBAR}"

# Small function to print the filename
# Note that this function gets redefined over and over again for each tool.
# It's of no use when building the toolchain proper, but shows all its
# usefullness when saving the toolchain and building the tarball.
# You shall not echo anything if you're not enabled!
# Echo the name of the file, without the extension, below.
do_print_filename() {
    # For example:
    # [ "{CT_FOOBAR}" = "y" ] || return 0
    # echo "foobar-${CT_FOOBAR_VERSION}"
    :
}

# Put your download code here
do_tools_foobar_get() {
    # For example:
    # CT_GetFile "foobar-${CT_FOOBAR_VERSION}" http://foobar.com/releases/
    :
}

# Put your extract code here
do_tools_foobar_extract() {
    # For example:
    # CT_ExtractAndPatch "foobar-${CT_FOOBAR_VERSION}"
    :
}

# Put your build code here
do_tools_foobar_build() {
    # For example:
    # mkdir -p "${CT_BUILD_DIR}/build-foobar"
    # CT_Pushd "${CT_BUILD_DIR}/build-foobar"
    # CT_DoExecLog ALL                                        \
    # "${CT_SRC_DIR}/foobar-${CT_FOOBAR_VERSION}/configure"   \
    #     --build=${CT_BUILD}                                 \
    #     --host=${CT_TARGET}                                 \
    #     --prefix=/usr                                       \
    #     --foobar-options
    # CT_DoExecLog ALL make
    # CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" install
    # CT_Popd
    :
}

