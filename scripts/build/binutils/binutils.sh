# This file adds functions to build binutils
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download binutils
do_binutils_get() {
    if [ "${CT_BINUTILS_CUSTOM}" = "y" ]; then
        CT_GetCustom "binutils" "${CT_BINUTILS_VERSION}" \
                     "${CT_BINUTILS_CUSTOM_LOCATION}"
    else
        if echo ${CT_BINUTILS_VERSION} |${grep} -q linaro; then
            YYMM=`echo ${CT_BINUTILS_VERSION} |cut -d- -f3 |${sed} -e 's,^..,,'`
            CT_GetFile "binutils-${CT_BINUTILS_VERSION}"                                        \
                       https://releases.linaro.org/${YYMM}/components/toolchain/binutils-linaro \
                       http://cbuild.validation.linaro.org/snapshots
        else
            CT_GetFile "binutils-${CT_BINUTILS_VERSION}"                                        \
                       {http,ftp}://{ftp.gnu.org/gnu,ftp.kernel.org/pub/linux/devel}/binutils   \
                       ftp://{sourceware.org,gcc.gnu.org}/pub/binutils/{releases,snapshots}
        fi
    fi

    if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then
        if [ "${CT_ELF2FLT_CUSTOM}" = "y" ]; then
            CT_GetCustom "elf2flt" "${CT_ELF2FLT_VERSION}"  \
                         "${CT_ELF2FLT_CUSTOM_LOCATION}"
        else
            CT_GetGit elf2flt "${CT_ELF2FLT_GIT_CSET}" git://wh0rd.org/elf2flt.git
        fi
    fi
}

# Extract binutils
do_binutils_extract() {
    # If using custom directory location, nothing to do
    if ! [ "${CT_BINUTILS_CUSTOM}" = "y" \
         -a -d "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}" ]; then
        CT_Extract "binutils-${CT_BINUTILS_VERSION}"
        CT_Patch "binutils" "${CT_BINUTILS_VERSION}"
    fi

    if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then
        if ! [ "${CT_ELF2FLT_CUSTOM}" = "y" \
             -a -d "${CT_SRC_DIR}/elf2flt-${CT_ELF2FLT_VERSION}" ]; then
            CT_Extract "elf2flt-${CT_ELF2FLT_GIT_CSET}"
            CT_Patch "elf2flt" "${CT_ELF2FLT_GIT_CSET}"
        fi
    fi

    if [ -n "${CT_ARCH_XTENSA_CUSTOM_NAME}" ]; then
        CT_ConfigureXtensa "binutils" "${CT_BINUTILS_VERSION}"
    fi
}

# Build binutils for build -> target
do_binutils_for_build() {
    local -a binutils_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing binutils for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-binutils-build-${CT_BUILD}"

    binutils_opts+=( "host=${CT_BUILD}" )
    binutils_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    binutils_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    binutils_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )

    do_binutils_backend "${binutils_opts[@]}"

    CT_Popd

    if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then
        # We re-use binutils' options, plus our owns
        binutils_opts+=( "binutils_src=${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}" )
        binutils_opts+=( "binutils_bld=${CT_BUILD_DIR}/build-binutils-build-${CT_BUILD}" )

        CT_mkdir_pushd "${CT_BUILD_DIR}/build-elf2flt-build-${CT_BUILD}"

        do_elf2flt_backend "${binutils_opts[@]}"

        CT_Popd
    fi

    CT_EndStep
}

# Build binutils for host -> target
do_binutils_for_host() {
    local -a binutils_tools
    local -a binutils_opts

    CT_DoStep INFO "Installing binutils for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-binutils-host-${CT_HOST}"

    binutils_opts+=( "host=${CT_HOST}" )
    binutils_opts+=( "prefix=${CT_PREFIX_DIR}" )
    binutils_opts+=( "static_build=${CT_STATIC_TOOLCHAIN}" )
    binutils_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    binutils_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    binutils_opts+=( "build_manuals=${CT_BUILD_MANUALS}" )

    do_binutils_backend "${binutils_opts[@]}"

    CT_Popd

    if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then
        # We re-use binutils' options, plus our owns
        binutils_opts+=( "binutils_src=${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}" )
        binutils_opts+=( "binutils_bld=${CT_BUILD_DIR}/build-binutils-host-${CT_HOST}" )

        CT_mkdir_pushd "${CT_BUILD_DIR}/build-elf2flt-host-${CT_HOST}"

        do_elf2flt_backend "${binutils_opts[@]}"

        CT_Popd
    fi

    # Make those new tools available to the core C compilers to come.
    # Note: some components want the ${TARGET}-{ar,as,ld,ranlib,strip} commands
    # as well. Create that.
    # Don't do it for canadian or cross-native, because the binutils
    # are not executable on the build machine.
    case "${CT_TOOLCHAIN_TYPE}" in
        cross|native)
            binutils_tools=( ar as ld ranlib strip )
            if [ -n "${CT_ARCH_BINFMT_FLAT}" ]; then
                binutils_tools+=( elf2flt flthdr )
            fi
            case "${CT_BINUTILS_LINKERS_LIST}" in
                ld)         binutils_tools+=( ld.bfd ) ;;
                gold)       binutils_tools+=( ld.gold ) ;;
                ld,gold)    binutils_tools+=( ld.bfd ld.gold ) ;;
                gold,ld)    binutils_tools+=( ld.bfd ld.gold ) ;;
            esac
            mkdir -p "${CT_BUILDTOOLS_PREFIX_DIR}/${CT_TARGET}/bin"
            mkdir -p "${CT_BUILDTOOLS_PREFIX_DIR}/bin"
            for t in "${binutils_tools[@]}"; do
                CT_DoExecLog ALL ln -sv                                         \
                                    "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}"    \
                                    "${CT_BUILDTOOLS_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
                CT_DoExecLog ALL ln -sv                                         \
                                    "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}"    \
                                    "${CT_BUILDTOOLS_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
            done
            ;;
        *)  ;;
    esac

    CT_EndStep
}

# Build binutils for X -> target
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     static_build  : build statcially          : bool      : no
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     build_manuals : whether to build manuals  : bool      : no
do_binutils_backend() {
    local host
    local prefix
    local static_build
    local cflags
    local ldflags
    local build_manuals=no
    local -a extra_config
    local -a extra_make_flags
    local -a manuals_for
    local -a manuals_install
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring binutils"

    if [ "${CT_BINUTILS_HAS_GOLD}" = "y" ]; then
        case "${CT_BINUTILS_LINKERS_LIST}" in
            ld)
                extra_config+=( --enable-ld=yes --enable-gold=no )
                ;;
            gold)
                extra_config+=( --enable-ld=no --enable-gold=yes )
                ;;
            ld,gold)
                extra_config+=( --enable-ld=default --enable-gold=yes )
                ;;
            gold,ld)
                extra_config+=( --enable-ld=yes --enable-gold=default )
                ;;
        esac
        if [ "${CT_BINUTILS_GOLD_THREADS}" = "y" ]; then
            extra_config+=( --enable-threads )
        fi
    fi
    if [ "${CT_BINUTILS_PLUGINS}" = "y" ]; then
        extra_config+=( --enable-plugins )
    fi
    if [ "${CT_BINUTILS_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi
    if [ "${CT_MULTILIB}" = "y" ]; then
        extra_config+=("--enable-multilib")
    else
        extra_config+=("--disable-multilib")
    fi

    [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    CT_DoExecLog CFG                                            \
    CFLAGS="${cflags}"                                          \
    CXXFLAGS="${cflags}"                                        \
    LDFLAGS="${ldflags}"                                        \
    "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
        --build=${CT_BUILD}                                     \
        --host=${host}                                          \
        --target=${CT_TARGET}                                   \
        --prefix=${prefix}                                      \
        --disable-werror                                        \
        "${extra_config[@]}"                                    \
        ${CT_ARCH_WITH_FLOAT}                                   \
        ${BINUTILS_SYSROOT_ARG}                                 \
        "${CT_BINUTILS_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${static_build}" = "y" ]; then
        extra_make_flags+=("LDFLAGS=-all-static")
        CT_DoLog EXTRA "Prepare binutils for static build"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} configure-host
    fi

    CT_DoLog EXTRA "Building binutils"
    CT_DoExecLog ALL ${make} "${extra_make_flags[@]}" ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing binutils"
    CT_DoExecLog ALL ${make} install

    if [ "${build_manuals}" = "y" ]; then
        CT_DoLog EXTRA "Building and installing the binutils manuals"
        manuals_for=( gas binutils ld gprof )
        if [ "${CT_BINUTILS_LINKER_GOLD}" = "y" ]; then
            manuals_for+=( gold )
        fi
        manuals_install=( "${manuals_for[@]/#/install-pdf-}" )
        manuals_install+=( "${manuals_for[@]/#/install-html-}" )
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} pdf html
        CT_DoExecLog ALL ${make} "${manuals_install[@]}"
    fi

    # Install the wrapper if needed
    if [ "${CT_BINUTILS_LD_WRAPPER}" = "y" ]; then
        CT_DoLog EXTRA "Installing ld wrapper"
        rm -f "${prefix}/bin/${CT_TARGET}-ld"
        rm -f "${prefix}/${CT_TARGET}/bin/ld"
        ${sed} -r -e "s/@@DEFAULT_LD@@/${CT_BINUTILS_LINKER_DEFAULT}/" \
            "${CT_LIB_DIR}/scripts/build/binutils/binutils-ld.in"      \
            >"${prefix}/bin/${CT_TARGET}-ld"
        chmod +x "${prefix}/bin/${CT_TARGET}-ld"
        cp -a "${prefix}/bin/${CT_TARGET}-ld"   \
              "${prefix}/${CT_TARGET}/bin/ld"

        # If needed, force using ld.bfd during the toolchain build
        if [ "${CT_BINUTILS_FORCE_LD_BFD}" = "y" ]; then
            export CTNG_LD_IS=bfd
        fi
    fi
}

# Build elf2flt for X -> target
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     static_build  : build statcially          : bool      : no
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
#     binutils_src  : source dir of binutils    : dir       : (none)
#     binutils_bld  : build dir of binutils     : dir       : (none)
#     build_manuals : whether to build manuals  : bool      : no
do_elf2flt_backend() {
    local host
    local prefix
    local static_build
    local cflags
    local ldflags
    local binutils_bld
    local binutils_src
    local build_manuals
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring elf2flt"
    CT_DoExecLog CFG                                            \
    CFLAGS="${cflags}"                                          \
    LDFLAGS="${ldflags}"                                        \
    LIBS="-ldl"                                                 \
    "${CT_SRC_DIR}/elf2flt-${CT_ELF2FLT_VERSION}/configure"     \
        --build=${CT_BUILD}                                     \
        --host=${host}                                          \
        --target=${CT_TARGET}                                   \
        --prefix=${prefix}                                      \
        --with-bfd-include-dir=${binutils_bld}/bfd              \
        --with-binutils-include-dir=${binutils_src}/include     \
        --with-libbfd=${binutils_bld}/bfd/libbfd.a              \
        --with-libiberty=${binutils_bld}/libiberty/libiberty.a  \
        ${elf2flt_opts}                                         \
        "${CT_ELF2FLT_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building elf2flt"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing elf2flt"
    CT_DoExecLog ALL ${make} install
}

# Now on for the target libraries
do_binutils_for_target() {
    local -a extra_config
    local -a targets
    local -a build_targets
    local -a install_targets
    local t

    [ "${CT_BINUTILS_FOR_TARGET_IBERTY}" = "y" ] && targets+=("libiberty")
    [ "${CT_BINUTILS_FOR_TARGET_BFD}"    = "y" ] && targets+=("bfd")
    for t in "${targets[@]}"; do
        build_targets+=("all-${t}")
        install_targets+=("install-${t}")
    done

    if [ "${#targets[@]}" -ne 0 ]; then
        CT_DoStep INFO "Installing binutils for target"
        mkdir -p "${CT_BUILD_DIR}/build-binutils-for-target"
        CT_Pushd "${CT_BUILD_DIR}/build-binutils-for-target"

        CT_DoLog EXTRA "Configuring binutils for target"

        if [ "${CT_BINUTILS_HAS_PKGVERSION_BUGURL}" = "y" ]; then
            extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
            [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
        fi
        if [ "${CT_MULTILIB}" = "y" ]; then
            extra_config+=("--enable-multilib")
        else
            extra_config+=("--disable-multilib")
        fi

        [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

        CT_DoExecLog CFG                                            \
        "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
            --build=${CT_BUILD}                                     \
            --host=${CT_TARGET}                                     \
            --target=${CT_TARGET}                                   \
            --prefix=/usr                                           \
            --disable-werror                                        \
            --enable-shared                                         \
            --enable-static                                         \
            "${extra_config[@]}"                                    \
            ${CT_ARCH_WITH_FLOAT}                                   \
            "${CT_BINUTILS_EXTRA_CONFIG_ARRAY[@]}"

        CT_DoLog EXTRA "Building binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS} "${build_targets[@]}"
        CT_DoLog EXTRA "Installing binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL ${make} DESTDIR="${CT_SYSROOT_DIR}" "${install_targets[@]}"

        CT_Popd
        CT_EndStep
    fi
}
