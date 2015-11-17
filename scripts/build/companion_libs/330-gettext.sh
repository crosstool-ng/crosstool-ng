# Build script for gettext

do_gettext_get() { :; }
do_gettext_extract() { :; }
do_gettext_for_build() { :; }
do_gettext_for_host() { :; }
do_gettext_for_target() { :; }

if [ "${CT_GETTEXT}" = "y" ]; then

do_gettext_get() {
    CT_GetFile "gettext-${CT_GETTEXT_VERSION}" \
               http://ftp.gnu.org/pub/gnu/gettext/
}

do_gettext_extract() {
    CT_Extract "gettext-${CT_GETTEXT_VERSION}"
    CT_Patch "gettext" "${CT_GETTEXT_VERSION}"
}

# Build gettext for running on build
do_gettext_for_build() {
    local -a gettext_opts

    case "$CT_BUILD" in
        *linux*)
            return 0
            ;;
    esac

    CT_DoStep INFO "Installing gettext for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gettext-build-${CT_BUILD}"

    gettext_opts+=( "host=${CT_BUILD}" )
    gettext_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    gettext_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    gettext_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    gettext_opts+=( "static_build=y" )
    do_gettext_backend "${gettext_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build gettext for running on host
do_gettext_for_host() {
    local -a gettext_opts

    case "$CT_HOST" in
        *linux*)
            return 0
            ;;
    esac

    CT_DoStep INFO "Installing gettext for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gettext-host-${CT_HOST}"

    gettext_opts+=( "host=${CT_HOST}" )
    gettext_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    gettext_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    gettext_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    gettext_opts+=( "static_build=${CT_STATIC_TOOLCHAIN}" )
    do_gettext_backend "${gettext_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build gettext
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     static_build  : build statically          : bool      : no
#     cflags        : host cflags to use        : string    : (empty)
#     ldflags       : host ldflags to use       : string    : (empty)
do_gettext_backend() {
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

    CT_DoLog EXTRA "Configuring gettext"

    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/gettext-${CT_GETTEXT_VERSION}/"/* .

    # A bit ugly. D__USE_MINGW_ANSI_STDIO=1 has its own {v}asprintf functions
    # but gettext configure doesn't see this flag when it checks for that. An
    # alternative may be to use CC="${host}-gcc ${cflags}" but that didn't
    # work.
    # -O2 works around bug at http://savannah.gnu.org/bugs/?36443
    # gettext needs some fixing for MinGW-w64 it would seem.
    case "${host}" in
        *mingw*)
            case "${cflags}" in
                *D__USE_MINGW_ANSI_STDIO=1*)
                    extra_config+=( --disable-libasprintf )
                    ;;
            esac
            extra_config+=( --enable-threads=win32 )
            cflags=$cflags" -O2"
        ;;
    esac

    if [ "${static_build}" = "y" ]; then
        extra_config+=("--disable-shared")
        extra_config+=("--enable-static")
    fi

    CT_DoExecLog CFG                                        \
    CFLAGS="${cflags}"                                      \
    LDFLAGS="${ldflags}"                                    \
    "${CT_SRC_DIR}/gettext-${CT_GETTEXT_VERSION}/configure" \
        --build=${CT_BUILD}                                 \
        --host="${host}"                                    \
        --prefix="${prefix}"                                \
        --disable-java                                      \
        --disable-native-java                               \
        --disable-csharp                                    \
        --without-emacs                                     \
        --disable-openmp                                    \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building gettext"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing gettext"
    CT_DoExecLog ALL ${make} install
}

fi
