# Build script for gnuprumcu

do_gnuprumcu_get() { :; }
do_gnuprumcu_extract() { :; }
do_gnuprumcu_for_build() { :; }
do_gnuprumcu_for_host() { :; }
do_gnuprumcu_for_target() { :; }

if [ "${CT_COMP_LIBS_GNUPRUMCU}" = "y" ]; then

do_gnuprumcu_get() {
    CT_Fetch GNUPRUMCU
}

do_gnuprumcu_extract() {
    CT_ExtractPatch GNUPRUMCU
}


do_gnuprumcu_for_target() {
    local -a gnuprumcu_opts

    CT_DoStep INFO "Installing gnuprumcu for the target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-gnuprumcu-target-${CT_TARGET}"

    gnuprumcu_opts+=( "destdir=${CT_SYSROOT_DIR}" )
    gnuprumcu_opts+=( "host=${CT_HOST}" )

    gnuprumcu_opts+=( "cflags=${CT_ALL_TARGET_CFLAGS}" )
    gnuprumcu_opts+=( "prefix=${CT_PREFIX_DIR}" )
    do_gnuprumcu_backend "${gnuprumcu_opts[@]}"

    CT_Popd
    CT_EndStep
}


# Build gnuprumcu
#     Parameter     : description               : type      : default
#     destdir       : out-of-tree install dir   : string    : /
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     shared        : also buils shared lib     : bool      : n
do_gnuprumcu_backend() {
    local destdir="/"
    local host
    local prefix
    local cflags
    local ldflags
    local shared
    local -a extra_config
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring gnuprumcu"

    CT_DoExecLog CFG                                        \
    CC="${host}-gcc"                                        \
    RANLIB="${host}-ranlib"                                 \
    CFLAGS="${cflags}"                                      \
    LDFLAGS="${ldflags}"                                    \
    ${CONFIG_SHELL}                                         \
    "${CT_SRC_DIR}/gnuprumcu/configure"                     \
        --build=${CT_BUILD}                                 \
        --host=${host}                                      \
        --target=${CT_TARGET}                               \
        --prefix="${prefix}"                                \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building gnuprumcu"
    CT_DoExecLog ALL make

    CT_DoLog EXTRA "Installing gnuprumcu"

    # Guard against $destdir$prefix == //
    # which is a UNC path on Cygwin/MSYS2
    if [[ ${destdir} == / ]] && [[ ${prefix} == /* ]]; then
        destdir=
    fi

    CT_DoExecLog ALL make instroot="${destdir}" install
}

fi # CT_COMP_LIBS_GNUPRUMCU
