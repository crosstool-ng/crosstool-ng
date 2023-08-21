# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

glibc_get()
{
    local date
    local version

    CT_Fetch GLIBC
    return 0
}

glibc_extract()
{
    CT_ExtractPatch GLIBC
}

# This function builds and install the full C library
glibc_main()
{
    local arg

    CT_DoStep INFO "Installing C library"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc"
    CT_IterateMultilibs glibc_backend_once multilib
    CT_Popd
    CT_EndStep
}

# This backend builds the C library once
# Usage: glibc_backend_once param=value [...]
#   Parameter           : Definition                            : Type
#   multi_*             : as defined in CT_IterateMultilibs     : (varies)  :
glibc_backend_once()
{
    # Glibc seems to be smart enough to know about the cases that can coexist
    # in the same root and installs them into proper multilib-os directory; all
    # we need is to point to the right root.
    local multi_flags multi_dir multi_os_dir multi_root multi_index multi_count multi_target
    local build_cflags build_cppflags build_ldflags
    local src_dir="${CT_SRC_DIR}/glibc"
    local -a extra_config
    local -a extra_make_args
    local glibc_cflags
    local arg opt

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoStep INFO "Building for multilib ${multi_index}/${multi_count}: '${multi_flags}'"

    # Ensure sysroot (with suffix, if applicable) exists
    CT_DoExecLog ALL mkdir -p "${multi_root}"

    # Adjust target tuple according GLIBC quirks
    CT_DoArchGlibcAdjustTuple multi_target

    CT_DoLog EXTRA "Configuring C library"

    # If those two are missing, iconv build breaks
    extra_config+=( --disable-debug --disable-sanity-checks )

    if [ "${CT_GLIBC_ENABLE_OBSOLETE_RPC}" = "y" ]; then
        extra_config+=( --enable-obsolete-rpc )
    fi

    if [ "${CT_GLIBC_ENABLE_OBSOLETE_LIBCRYPT}" = "y" ]; then
        extra_config+=( --enable-crypt )
    fi

    # Add some default glibc config options if not given by user.
    # We don't need to be conditional on whether the user did set different
    # values, as they CT_GLIBC_EXTRA_CONFIG_ARRAY is passed after
    # extra_config

    extra_config+=("$(glibc_min_kernel_config)")

    case "${CT_THREADS}" in
        nptl)           extra_config+=("--with-__thread" "--with-tls");;
        linuxthreads)   extra_config+=("--with-__thread" "--without-tls" "--without-nptl");;
        none)           extra_config+=("--without-__thread" "--without-nptl")
                        case "${CT_GLIBC_EXTRA_CONFIG_ARRAY[*]}" in
                            *-tls*) ;;
                            *) extra_config+=("--without-tls");;
                        esac
                        ;;
    esac

    # FIXME static version of glibc seems to be broken:
    # build tries to use libc-modules.h which is generated from
    # soversions.i, which is only created for builds with shared libs.
    case "${CT_SHARED_LIBS}" in
        y) extra_config+=("--enable-shared");;
        *) extra_config+=("--disable-shared");;
    esac

    if [ "${CT_GLIBC_DISABLE_VERSIONING}" = "y" ]; then
        extra_config+=("--disable-versioning")
    fi

    if [ "${CT_GLIBC_OLDEST_ABI}" != "" ]; then
        extra_config+=("--enable-oldest-abi=${CT_GLIBC_OLDEST_ABI}")
    fi

    case "$(glibc_add_ons_list ,)" in
        "") extra_config+=("--enable-add-ons=no");;
        *)  extra_config+=("--enable-add-ons=$(glibc_add_ons_list ,)");;
    esac

    [ "${CT_GLIBC_ENABLE_WERROR}" != "y" ] && extra_config+=("--disable-werror")
    [ -n "${CT_PKGVERSION}" ] && extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")

    if [ -n "${CT_GLIBC_SSP}" ]; then
        extra_config+=("--enable-stack-protector=${CT_GLIBC_SSP}")
    fi

    touch config.cache

    # Until it became explicitly controllable with --enable-stack-protector=...,
    # configure detected GCC support for -fstack-protector{,-strong} and
    # tried to enable it in some parts of glibc - which then failed to build.
    if [ -z "${CT_GLIBC_BUILD_SSP}" ]; then
        echo "libc_cv_ssp=no" >>config.cache
        echo "libc_cv_ssp_strong=no" >>config.cache
    fi

    if [ "${CT_GLIBC_FORCE_UNWIND}" = "y" ]; then
        echo "libc_cv_forced_unwind=yes" >>config.cache
        echo "libc_cv_c_cleanup=yes" >>config.cache
    fi

    # Pre-seed the configparms file with values from the config option
    printf "%s\n" "${CT_GLIBC_CONFIGPARMS}" > configparms

   if [ "${CT_GLIBC_ENABLE_DEBUG}" = "y" ]; then
        glibc_cflags+=" -g"
   fi

    # glibc can't be built without -O2 (reference needed!)
    glibc_cflags+=" -O2"

    if [ "${CT_GLIBC_ENABLE_COMMON_FLAG}" = "y" ]; then
        glibc_cflags+=" -fcommon"
    fi

    case "${CT_GLIBC_ENABLE_FORTIFIED_BUILD}" in
        y)  ;;
        *)  glibc_cflags+=" -U_FORTIFY_SOURCE";;
    esac

    # In the order of increasing precedence. Flags common to compiler and linker.
    glibc_cflags+=" ${CT_ALL_TARGET_CFLAGS}"
    glibc_cflags+=" ${CT_GLIBC_EXTRA_CFLAGS}"
    glibc_cflags+=" ${multi_flags}"

    # Analyze the resulting options for any extra configure switches to throw in.
    for opt in ${glibc_cflags}; do
        case ${opt} in
            -mhard-float|-mfloat-abi=hard|-mfloat-abi=softfp|-mno-soft-float|-mfpu)
                extra_config+=("--with-fp")
                ;;
            -msoft-float|-mfloat-abi=soft|-mno-float|-mno-fpu)
                extra_config+=("--without-fp")
                ;;
        esac
    done
    CT_DoArchGlibcAdjustConfigure extra_config "${glibc_cflags}"

    # ./configure is mislead by our tools override wrapper for bash
    # so just tell it where the real bash is _on_the_target_!
    # Notes:
    # - ${ac_cv_path_BASH_SHELL} is only used to set BASH_SHELL
    # - ${BASH_SHELL}            is only used to set BASH
    # - ${BASH}                  is only used to set the shebang
    #                            in two scripts to run on the target
    # So we can safely bypass bash detection at compile time.
    # Should this change in a future glibc release, we'd better
    # directly mangle the generated scripts _after_ they get built,
    # or even after they get installed...
    echo "ac_cv_path_BASH_SHELL=/bin/bash" >>config.cache

    CT_SymlinkToolsMultilib

    # Configure with --prefix the way we want it on the target...
    # There are a whole lot of settings here.  You'll probably want
    # to read up on what they all mean, and customize a bit, possibly
    # by setting GLIBC_EXTRA_CONFIG_ARRAY.
    # Compare these options with the ones used when installing
    # the glibc headers above - they're different.
    # Adding "--without-gd" option to avoid error "memusagestat.c:36:16:
    # gd.h: No such file or directory"
    # See also http://sources.redhat.com/ml/libc-alpha/2000-07/msg00024.html.
    # Set BUILD_CC, or we won't be able to build datafiles
    # Run explicitly through CONFIG_SHELL, or the build breaks badly (loop-of-death)
    # when the shell is not bash... Sigh... :-(

    CT_DoLog DEBUG "Configuring with addons  : '$(glibc_add_ons_list ,)'"
    CT_DoLog DEBUG "Extra config args passed : '${extra_config[*]}'"
    CT_DoLog DEBUG "Extra CFLAGS passed      : '${glibc_cflags}'"
    CT_DoLog DEBUG "Configuring with --host  : '${multi_target}'"

    # CFLAGS are only applied when compiling .c files. .S files are compiled with ASFLAGS,
    # but they are not passed by configure. Thus, pass everything in CC instead.
    # The CFLAGS variable needs to be cleared, else the default "-g -O2"
    # would override previous flags.
    CT_DoExecLog CFG                                                \
    BUILD_CC=${CT_BUILD}-gcc                                        \
    CC="${CT_TARGET}-${CT_CC} ${glibc_cflags}"                      \
    CFLAGS=""                                                       \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    "${CONFIG_SHELL}"                                               \
    "${src_dir}/configure"                                          \
        --prefix=/usr                                               \
        --build=${CT_BUILD}                                         \
        --host=${multi_target}                                      \
        --cache-file="$(pwd)/config.cache"                          \
        --without-cvs                                               \
        --disable-profile                                           \
        --without-gd                                                \
        --with-headers="${CT_HEADERS_DIR}"                          \
        "${extra_config[@]}"                                        \
        "${CT_GLIBC_EXTRA_CONFIG_ARRAY[@]}"

    # build hacks

    # Mask C++ compiler. Glibc 2.29+ attempts to build some tests using gcc++, but
    # we haven't built libstdc++ yet. Should really implement #808 after 1.24.0...
    extra_make_args+=( CXX= )
    case "${CT_ARCH},${CT_ARCH_CPU}" in
        powerpc,8??)
            # http://sourceware.org/ml/crossgcc/2008-10/msg00068.html
            CT_DoLog DEBUG "Activating support for memset on broken ppc-8xx (CPU15 erratum)"
            extra_make_args+=( ASFLAGS="-DBROKEN_PPC_8xx_CPU15" )
            ;;
    esac

    build_cflags="${CT_CFLAGS_FOR_BUILD}"
    build_cppflags=
    build_ldflags="${CT_LDFLAGS_FOR_BUILD}"

    case "$CT_BUILD" in
        *mingw*|*cygwin*|*msys*|*darwin*|*freebsd*)
            # When installing headers on Cygwin, Darwin, MSYS2 and MinGW-w64 sunrpc needs
            # gettext for building cross-rpcgen.
            build_cppflags="${build_cppflags} -I${CT_BUILDTOOLS_PREFIX_DIR}/include/"
            build_ldflags="${build_ldflags} -lintl -liconv"
            case "$CT_BUILD" in
                *cygwin*|*freebsd*)
                # Additionally, stat in FreeBSD, Cygwin, and possibly others
                # is always 64bit, so replace struct stat64 with stat.
                build_cppflags="${build_cppflags} -Dstat64=stat"
                ;;
            esac
            ;;
    esac

    # Make sure glibc build system respects our provided CFLAGS.
    extra_make_args+=( default_cflags= )
    extra_make_args+=( "BUILD_CFLAGS=${build_cflags}" )
    extra_make_args+=( "BUILD_CPPFLAGS=${build_cppflags}" )
    extra_make_args+=( "BUILD_LDFLAGS=${build_ldflags}" )

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}         \
                          "${extra_make_args[@]}" \
                          all

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}                 \
                          "${extra_make_args[@]}"         \
                          install_root="${multi_root}"    \
                          install

    if [ "${CT_BUILD_MANUALS}" = "y" -a "${multi_index}" = "${multi_count}" ]; then
        # We only need to build the manuals once. Only build them on the
        # last multilib target. If it's not multilib, it will happen on the
        # only target.
        CT_DoLog EXTRA "Building and installing the C library manual"
        # Omit CT_JOBSFLAGS as GLIBC has problems building the
        # manuals in parallel
        CT_DoExecLog ALL make pdf html
        CT_DoExecLog ALL mkdir -p ${CT_PREFIX_DIR}/share/doc
        CT_DoExecLog ALL cp -av manual/*.pdf    \
                                manual/libc     \
                                ${CT_PREFIX_DIR}/share/doc
    fi

    if [ "${CT_GLIBC_LOCALES}" = "y" -a "${multi_index}" = "${multi_count}" ]; then
        glibc_locales
    fi

    CT_EndStep
}

# Build up the addons list, separated with $1
glibc_add_ons_list()
{
    local sep="$1"
    local addons_list

    if [ "${CT_GLIBC_USE_PORTS_ADDON}" = "y" ]; then
        addons_list="${addons_list}${sep}ports"
    fi
    if [ "${CT_GLIBC_USE_NPTL_ADDON}" = "y" ]; then
        addons_list="${addons_list}${sep}nptl"
    fi
    if [ "${CT_GLIBC_USE_LIBIDN_ADDON}" = "y" ]; then
        addons_list="${addons_list}${sep}libidn"
    fi
    echo "${addons_list#${sep}}" # Remove leading separator if any
}

# Compute up the minimum supported Linux kernel version
glibc_min_kernel_config()
{
    local min_kernel_config

    case "${CT_GLIBC_EXTRA_CONFIG_ARRAY[*]}" in
        *--enable-kernel*) ;;
        *)  if [ "${CT_GLIBC_KERNEL_VERSION_AS_HEADERS}" = "y" ]; then
                # TBD do we support that currently? We always seem to install kernel headers
                # We can't rely on the kernel version from the configuration,
                # because it might not be available if the user uses pre-installed
                # headers. On the other hand, both method will have the kernel
                # version installed in "usr/include/linux/version.h" in the sysroot.
                # Parse that instead of having two code-paths.
                version_code_file="${CT_SYSROOT_DIR}/usr/include/linux/version.h"
                if [ ! -f "${version_code_file}" -o ! -r "${version_code_file}" ]; then
                    CT_Abort "Linux version is unavailable in installed headers files"
                fi
                version_code="$(grep -E LINUX_VERSION_CODE "${version_code_file}"  \
                                 |cut -d' ' -f 3                                      \
                               )"
                version=$(((version_code>>16)&0xFF))
                patchlevel=$(((version_code>>8)&0xFF))
                sublevel=$((version_code&0xFF))
                min_kernel_config="${version}.${patchlevel}.${sublevel}"
            elif [ "${CT_GLIBC_KERNEL_VERSION_CHOSEN}" = "y" ]; then
                # Trim the fourth part of the linux version, keeping only the first three numbers
                min_kernel_config="$( echo "${CT_GLIBC_MIN_KERNEL_VERSION}"               \
                                      |sed -r -e 's/^([^.]+\.[^.]+\.[^.]+)(|\.[^.]+)$/\1/;' \
                                    )"
            fi
            echo "--enable-kernel=${min_kernel_config}"
            ;;
    esac
}

# Build and install the libc locales
glibc_locales()
{
    local src_dir="${CT_SRC_DIR}/glibc"
    local -a extra_config
    local glibc_cflags

    # To build locales, we'd need to build glibc for the build machine.
    # Bail out if the host is not supported.
    case "${CT_BUILD}" in
        *-cygwin|*-darwin*)
            CT_DoLog EXTRA "Skipping GNU libc locales: incompatible build machine"
            return
            ;;
    esac

    mkdir -p "${CT_BUILD_DIR}/build-localedef"
    cd "${CT_BUILD_DIR}/build-localedef"

    CT_DoLog EXTRA "Configuring C library localedef"

    # Versions that don't support --with-pkgversion or --with-bugurl will cause
    # a harmless: `configure: WARNING: unrecognized options: --with-bugurl...`
    # If it's set, use it, if is a recognized option.
    if [ ! "${CT_TOOLCHAIN_PKGVERSION}" = "" ]; then
        [ -n "${CT_PKGVERSION}" ] && extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    fi
    if [ ! "${CT_TOOLCHAIN_BUGURL}" = "" ]; then
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    CT_DoLog DEBUG "Extra config args passed: '${extra_config[*]}'"

    glibc_cflags="-O2 -fno-stack-protector"
    case "${CT_GLIBC_ENABLE_FORTIFIED_BUILD}" in
        y)  ;;
        *)  glibc_cflags+=" -U_FORTIFY_SOURCE";;
    esac

    # ./configure is misled by our tools override wrapper for bash
    # so just tell it where the real bash is _on_the_target_!
    # Notes:
    # - ${ac_cv_path_BASH_SHELL} is only used to set BASH_SHELL
    # - ${BASH_SHELL}            is only used to set BASH
    # - ${BASH}                  is only used to set the shebang
    #                            in two scripts to run on the target
    # So we can safely bypass bash detection at compile time.
    # Should this change in a future glibc release, we'd better
    # directly mangle the generated scripts _after_ they get built,
    # or even after they get installed...
    echo "ac_cv_path_BASH_SHELL=/bin/bash" >>config.cache

    # Configure with --prefix the way we want it on the target...

    CT_DoExecLog CFG                       \
    CFLAGS="${glibc_cflags}"               \
    ${CONFIG_SHELL}                        \
    "${src_dir}/configure"                 \
        --prefix=/usr                      \
        --cache-file="$(pwd)/config.cache" \
        --without-cvs                      \
        --disable-profile                  \
        --without-gd                       \
        --disable-debug                    \
        --disable-sanity-checks            \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building C library localedef"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}

    # The target's endianness and uint32_t alignment should be passed as options
    # to localedef, but glibc's localedef does not support these options, which
    # means that the locale files generated here will be suitable for the target
    # only if it has the same endianness and uint32_t alignment as the host's.

    CT_DoLog EXTRA "Installing C library locales"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS}                  \
                          install_root="${CT_SYSROOT_DIR}" \
                          localedata/install-locales
}

