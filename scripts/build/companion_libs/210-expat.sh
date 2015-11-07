# Build script for expat

do_expat_get() { :; }
do_expat_extract() { :; }
do_expat_for_build() { :; }
do_expat_for_host() { :; }
do_expat_for_target() { :; }

if [ "${CT_EXPAT_TARGET}" = "y" -o "${CT_EXPAT}" = "y" ]; then

do_expat_get() {
    CT_GetFile "expat-${CT_EXPAT_VERSION}" .tar.gz    \
               http://downloads.sourceforge.net/project/expat/expat/${CT_EXPAT_VERSION}
}

do_expat_extract() {
    CT_Extract "expat-${CT_EXPAT_VERSION}"
    CT_Patch "expat" "${CT_EXPAT_VERSION}"
}

if [ "${CT_EXPAT_TARGET}" = "y" ]; then
do_expat_for_target() {
    CT_DoStep INFO "Installing expat for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-expat-target-${CT_TARGET}"

    do_expat_backend host="${CT_TARGET}" \
                     prefix="/usr" \
                     destdir="${CT_SYSROOT_DIR}"

    CT_Popd
    CT_EndStep
}
fi

# Build libexpat
#   Parameter     : description               : type      : default
#   host          : machine to run on         : tuple     : (none)
#   prefix        : prefix to install into    : dir       : (none)
#   destdir       : install destination       : dir       : (none)
do_expat_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring expat"

    CT_DoExecLog CFG                                                \
    "${CT_SRC_DIR}/expat-${CT_EXPAT_VERSION}/configure"             \
        --build=${CT_BUILD}                                         \
        --host=${host}                                              \
        --prefix="${prefix}"                                        \
        --enable-static                                             \
        --disable-shared

    CT_DoLog EXTRA "Building expat"
    CT_DoExecLog ALL make ${JOBSFLAGS}
    CT_DoLog EXTRA "Installing expat"
    CT_DoExecLog ALL make install INSTALL_ROOT="${destdir}"
}

fi
