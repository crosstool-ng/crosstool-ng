# Build script for libiconv

do_libiconv_get() { :; }
do_libiconv_extract() { :; }
do_libiconv_for_build() { :; }
do_libiconv_for_host() { :; }
do_libiconv_for_target() { :; }

if [ "${CT_LIBICONV}" = "y" ]; then

do_libiconv_get() {
    CT_GetFile "libiconv-${CT_LIBICONV_VERSION}" \
               http://ftp.gnu.org/pub/gnu/libiconv/
}

do_libiconv_extract() {
    CT_Extract "libiconv-${CT_LIBICONV_VERSION}"
    CT_Patch "libiconv" "${CT_LIBICONV_VERSION}"
}

# Build libiconv for running on build
do_libiconv_for_build() {
    local -a libiconv_opts

    case "$CT_BUILD" in
        *darwin*|*linux*)
            return 0
            ;;
    esac

    CT_DoStep INFO "Installing libiconv for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libiconv-build-${CT_BUILD}"

    libiconv_opts+=( "host=${CT_BUILD}" )
    libiconv_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    libiconv_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    libiconv_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    libiconv_opts+=( "static_build=y" )
    do_libiconv_backend "${libiconv_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build libiconv for running on host
do_libiconv_for_host() {
    local -a libiconv_opts

    case "$CT_HOST" in
        *darwin*|*linux*)
            return 0
            ;;
    esac

    CT_DoStep INFO "Installing libiconv for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libiconv-host-${CT_HOST}"

    libiconv_opts+=( "host=${CT_HOST}" )
    libiconv_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    libiconv_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    libiconv_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    libiconv_opts+=( "static_build=${CT_STATIC_TOOLCHAIN}" )
    do_libiconv_backend "${libiconv_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build libiconv
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     static_build  : build statically          : bool      : no
#     cflags        : host cflags to use        : string    : (empty)
#     ldflags       : host ldflags to use       : string    : (empty)
do_libiconv_backend() {
    local host
    local prefix
    local static_build
    local cflags
    local ldflags
    local arg
    local -a extra_config

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring libiconv"

    CT_DoExecLog ALL cp -aT "${CT_SRC_DIR}/libiconv-${CT_LIBICONV_VERSION}" "."

    if [ "${static_build}" = "y" ]; then
        extra_config+=("--disable-shared")
        extra_config+=("--enable-static")
    fi

    CT_DoExecLog CFG                                          \
    CFLAGS="${cflags}"                                        \
    LDFLAGS="${ldflags}"                                      \
    "${CT_SRC_DIR}/libiconv-${CT_LIBICONV_VERSION}/configure" \
        --build=${CT_BUILD}                                   \
        --host="${host}"                                      \
        --prefix="${prefix}"                                  \
        "${extra_config[@]}"                                  \

    CT_DoLog EXTRA "Building libiconv"
    CT_DoExecLog ALL ${make} CC="${host}-gcc ${cflags}" ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing libiconv"
    CT_DoExecLog ALL ${make} install CC="${host}-gcc ${cflags}"
}

fi
