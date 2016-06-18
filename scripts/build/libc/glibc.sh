# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    local date
    local version

    # Main source
    if [ "${CT_LIBC_GLIBC_CUSTOM}" = "y" ]; then
        CT_GetCustom "glibc" "${CT_LIBC_GLIBC_CUSTOM_VERSION}" \
            "${CT_LIBC_GLIBC_CUSTOM_LOCATION}"
    else
        if echo ${CT_LIBC_VERSION} |${grep} -q linaro; then
            # Linaro glibc releases come from regular downloads...
            YYMM=`echo ${CT_LIBC_VERSION} |cut -d- -f3 |${sed} -e 's,^..,,'`
            CT_GetFile "glibc-${CT_LIBC_VERSION}" \
                       https://releases.linaro.org/${YYMM}/components/toolchain/glibc-linaro \
                       http://cbuild.validation.linaro.org/snapshots
        else
            CT_GetFile "glibc-${CT_LIBC_VERSION}"                                        \
                       {http,ftp,https}://ftp.gnu.org/gnu/glibc                          \
                       ftp://{sourceware.org,gcc.gnu.org}/pub/glibc/{releases,snapshots}
        fi
    fi

    return 0
}

do_libc_extract() {
    CT_Extract "${CT_LIBC}-${CT_LIBC_VERSION}"
    CT_Pushd "${CT_SRC_DIR}/${CT_LIBC}-${CT_LIBC_VERSION}"
    # Attempt CT_PATCH only if NOT custom
    CT_Patch nochdir "${CT_LIBC}" "${CT_LIBC_VERSION}"

    # The configure files may be older than the configure.in files
    # if using a snapshot (or even some tarballs). Fake them being
    # up to date.
    find . -type f -name configure -exec touch {} \; 2>&1 |CT_DoLog ALL

    CT_Popd
}

do_libc_check_config() {
    :
}

# Build and install headers and start files
do_libc_start_files() {
    # Start files and Headers should be configured the same way as the
    # final libc, but built and installed differently.
    do_libc_backend libc_mode=startfiles
}

# This function builds and install the full C library
do_libc() {
    do_libc_backend libc_mode=final
}

do_libc_post_cc() {
    :
}

# This backend builds the C library once for each multilib
# variant the compiler gives us
# Usage: do_libc_backend param=value [...]
#   Parameter           : Definition                            : Type      : Default
#   libc_mode           : 'startfiles' or 'final'               : string    : (none)
do_libc_backend() {
    local libc_mode
    local -a multilibs
    local multilib
    local multi_dir
    local multi_flags
    local extra_dir
    local target
    local libc_headers libc_startfiles libc_full
    local hdr
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    case "${libc_mode}" in
        startfiles)
            CT_DoStep INFO "Installing C library headers & start files"
            hdr=y
            libc_startfiles=y
            libc_full=
            ;;
        final)
            CT_DoStep INFO "Installing C library"
            hdr=
            libc_startfiles=
            libc_full=y
            ;;
        *)  CT_Abort "Unsupported (or unset) libc_mode='${libc_mode}'";;
    esac

    # If gcc is not configured for multilib, it still prints
    # a single line for the default settings
    multilibs=( $("${CT_TARGET}-gcc" -print-multi-lib 2>/dev/null) )
    for multilib in "${multilibs[@]}"; do
        multi_dir="${multilib%%;*}"
        if [ "${multi_dir}" != "." ]; then
            CT_DoStep INFO "Building for multilib subdir='${multi_dir}'"

            extra_flags="$( echo "${multilib#*;}"       \
                            |${sed} -r -e 's/@/ -/g;'   \
                          )"
            extra_dir="/${multi_dir}"

            # glibc install its files in ${extra_dir}/{usr/,}lib
            # while gcc expects them in {,usr/}lib/${extra_dir}.
            # Prepare some symlinks so glibc installs in fact in
            # the proper place
            # We do it in the start-files step, so it is not needed
            # to do it in the final step, as the symlinks will
            # already exist
            if [ "${libc_mode}" = "startfiles" ]; then
                CT_Pushd "${CT_SYSROOT_DIR}"
                CT_DoExecLog ALL mkdir -p "lib/${multi_dir}"        \
                                          "usr/lib/${multi_dir}"    \
                                          "${multi_dir}"            \
                                          "${multi_dir}/usr"
                CT_DoExecLog ALL ln -sf "../lib/${multi_dir}" "${multi_dir}/lib"
                CT_DoExecLog ALL ln -sf "../../usr/lib/${multi_dir}" "${multi_dir}/usr/lib"
                CT_Popd
            fi
            libc_headers=
        else
            extra_dir=
            extra_flags=
            libc_headers="${hdr}"
        fi

        CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc-${libc_mode}${extra_dir//\//_}"

        target=$( CT_DoMultilibTarget "${CT_TARGET}" ${extra_flags} )
        case "${target}" in
            # SPARC quirk: glibc 2.23 and newer dropped support for SPARCv8 and
            # earlier (corresponding pthread barrier code is missing). Until this
            # support is reintroduced, configure as sparcv9.
            sparc-*)
                if [ "${CT_LIBC_GLIBC_2_23_or_later}" = y ]; then
                    target=${target/#sparc-/sparcv9-}
                fi
                ;;
            # x86 quirk: architecture name is i386, but glibc expects i[4567]86 - to
            # indicate the desired optimization. If it was a multilib variant of x86_64,
            # then it targets at least NetBurst a.k.a. i786, but we'll follow arch/x86.sh
            # and set the optimization to i686. Otherwise, replace with the most
            # conservative choice, i486.
            i386-*)
                if [ "${CT_TARGET_ARCH}" = "x86_64" ]; then
                    target=${target/#i386-/i686-}
                else
                    target=${target/#i386-/i486-}
                fi
                ;;
        esac

        do_libc_backend_once extra_dir="${extra_dir}"               \
                             extra_flags="${extra_flags}"           \
                             libc_headers="${libc_headers}"         \
                             libc_startfiles="${libc_startfiles}"   \
                             libc_full="${libc_full}"               \
                             target="${target}"

        CT_Popd

        if [ "${multi_dir}" != "." ]; then
            if [ "${libc_mode}" = "final" ]; then
                CT_DoLog EXTRA "Fixing up multilib location"

                # rewrite the library multiplexers
                for d in "lib/${multi_dir}" "usr/lib/${multi_dir}"; do
                    for l in libc libpthread libgcc_s; do
                        if [    -f "${CT_SYSROOT_DIR}/${d}/${l}.so"    \
                             -a ! -L ${CT_SYSROOT_DIR}/${d}/${l}.so    ]
                        then
                            CT_DoExecLog DEBUG ${sed} -r -i                                 \
                                                      -e "s:/lib/:/lib/${multi_dir}/:g;"    \
                                                      "${CT_SYSROOT_DIR}/${d}/${l}.so"
                        fi
                    done
                done
                # Remove the multi_dir now it is no longer useful
                CT_DoExecLog DEBUG rm -rf "${CT_SYSROOT_DIR}/${multi_dir}"
            fi # libc_mode == final

            CT_EndStep
        fi
    done

    CT_EndStep
}

# This backend builds the C library once
# Usage: do_libc_backend_once param=value [...]
#   Parameter           : Definition                            : Type      : Default
#   libc_headers        : Build libc headers                    : bool      : n
#   libc_startfiles     : Build libc start-files                : bool      : n
#   libc_full           : Build full libc                       : bool      : n
#   extra_flags         : Extra CFLAGS to use (for multilib)    : string    : (empty)
#   extra_dir           : Extra subdir for multilib             : string    : (empty)
#   target              : Build libc using this target (for multilib) : string : ${CT_TARGET}
do_libc_backend_once() {
    local libc_headers
    local libc_startfiles
    local libc_full
    local extra_flags
    local extra_dir
    local src_dir="${CT_SRC_DIR}/${CT_LIBC}-${CT_LIBC_VERSION}"
    local extra_cc_args
    local -a extra_config
    local -a extra_make_args
    local glibc_cflags
    local float_extra
    local endian_extra
    local target
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    if [ "${target}" = "" ]; then
        target="${CT_TARGET}"
    fi

    CT_DoLog EXTRA "Configuring C library"

    case "${CT_LIBC}" in
        glibc)
            # glibc can't be built without -O2 (reference needed!)
            OPTIMIZE=-O2
            # Also, if those two are missing, iconv build breaks
            extra_config+=( --disable-debug --disable-sanity-checks )
            ;;
    esac

    # always include rpc, the user can still override it with TI-RPC
    extra_config+=( --enable-obsolete-rpc )

    # Add some default glibc config options if not given by user.
    # We don't need to be conditional on wether the user did set different
    # values, as they CT_LIBC_GLIBC_EXTRA_CONFIG_ARRAY is passed after
    # extra_config

    extra_config+=("$(do_libc_min_kernel_config)")

    case "${CT_THREADS}" in
        nptl)           extra_config+=("--with-__thread" "--with-tls");;
        linuxthreads)   extra_config+=("--with-__thread" "--without-tls" "--without-nptl");;
        none)           extra_config+=("--without-__thread" "--without-nptl")
                        case "${CT_LIBC_GLIBC_EXTRA_CONFIG_ARRAY[*]}" in
                            *-tls*) ;;
                            *) extra_config+=("--without-tls");;
                        esac
                        ;;
    esac

    case "${CT_SHARED_LIBS}" in
        y) extra_config+=("--enable-shared");;
        *) extra_config+=("--disable-shared");;
    esac

    float_extra="$( echo "${extra_flags}"       \
                    |${sed} -r -e '/^(.*[[:space:]])?-m(hard|soft)-float([[:space:]].*)?$/!d;'  \
                               -e 's//\2/;'     \
                  )"
    case "${float_extra}" in
        hard)   extra_config+=("--with-fp");;
        soft)   extra_config+=("--without-fp");;
        "")
            case "${CT_ARCH_FLOAT}" in
                hard|softfp)    extra_config+=("--with-fp");;
                soft)           extra_config+=("--without-fp");;
            esac
            ;;
    esac

    if [ "${CT_LIBC_DISABLE_VERSIONING}" = "y" ]; then
        extra_config+=("--disable-versioning")
    fi

    if [ "${CT_LIBC_OLDEST_ABI}" != "" ]; then
        extra_config+=("--enable-oldest-abi=${CT_LIBC_OLDEST_ABI}")
    fi

    case "$(do_libc_add_ons_list ,)" in
        "") extra_config+=("--enable-add-ons=no");;
        *)  extra_config+=("--enable-add-ons=$(do_libc_add_ons_list ,)");;
    esac

    extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")

    # Extract the endianness options if any
    # This should cover all possible endianness options
    # in gcc, but it is prone to bit-rot... :-(
    endian_extra="$( echo "${extra_flags}"      \
                     |${sed} -r -e '/^(.*[[:space:]])?-(E[BL]|m((big|little)(-endian)?|e?[bl]))([[:space:]].*)?$/!d;' \
                                -e 's//\2/;'    \
                   )"
    # If extra_flags contained an endianness option, no need to add it again. Otherwise,
    # add the option from the configuration.
    case "${endian_extra}" in
        EB|mbig-endian|mbig|meb|mb)
            ;;
        EL|mlittle-endian|mlittle|mel|ml)
            ;;
        "") extra_cc_args="${extra_cc_args} ${CT_ARCH_ENDIAN_OPT}"
            ;;
    esac

    touch config.cache
    if [ "${CT_LIBC_GLIBC_FORCE_UNWIND}" = "y" ]; then
        echo "libc_cv_forced_unwind=yes" >>config.cache
        echo "libc_cv_c_cleanup=yes" >>config.cache
    fi

    # Pre-seed the configparms file with values from the config option
    printf "%s\n" "${CT_LIBC_GLIBC_CONFIGPARMS}" > configparms

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")
    extra_cc_args+=" ${extra_flags}"

    case "${CT_LIBC_ENABLE_FORTIFIED_BUILD}" in
        y)  ;;
        *)  glibc_cflags+=" -U_FORTIFY_SOURCE";;
    esac
    glibc_cflags+=" ${CT_TARGET_CFLAGS} ${OPTIMIZE} ${CT_LIBC_GLIBC_EXTRA_CFLAGS}"

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

    # Configure with --prefix the way we want it on the target...
    # There are a whole lot of settings here.  You'll probably want
    # to read up on what they all mean, and customize a bit, possibly by setting GLIBC_EXTRA_CONFIG_ARRAY
    # Compare these options with the ones used when installing the glibc headers above - they're different.
    # Adding "--without-gd" option to avoid error "memusagestat.c:36:16: gd.h: No such file or directory"
    # See also http://sources.redhat.com/ml/libc-alpha/2000-07/msg00024.html.
    # Set BUILD_CC, or we won't be able to build datafiles
    # Run explicitly through CONFIG_SHELL, or the build breaks badly (loop-of-death)
    # when the shell is not bash... Sigh... :-(

    CT_DoLog DEBUG "Using gcc for target    : '${cross_cc}'"
    CT_DoLog DEBUG "Configuring with addons : '$(do_libc_add_ons_list ,)'"
    CT_DoLog DEBUG "Extra config args passed: '${extra_config[*]}'"
    CT_DoLog DEBUG "Extra CC args passed    : '${glibc_cflags}'"
    CT_DoLog DEBUG "Extra flags (multilib)  : '${extra_flags}'"

    CT_DoExecLog CFG                                                \
    BUILD_CC="${CT_BUILD}-gcc"                                      \
    CFLAGS="${glibc_cflags}"                                        \
    CC="${CT_TARGET}-gcc ${CT_LIBC_EXTRA_CC_ARGS} ${extra_cc_args}" \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    "${CONFIG_SHELL}"                                               \
    "${src_dir}/configure"                                          \
        --prefix=/usr                                               \
        --build=${CT_BUILD}                                         \
        --host=${target}                                            \
        --cache-file="$(pwd)/config.cache"                          \
        --without-cvs                                               \
        --disable-profile                                           \
        --without-gd                                                \
        --with-headers="${CT_HEADERS_DIR}"                          \
        "${extra_config[@]}"                                        \
        "${CT_LIBC_GLIBC_EXTRA_CONFIG_ARRAY[@]}"

    # build hacks
    case "${CT_ARCH},${CT_ARCH_CPU}" in
        powerpc,8??)
            # http://sourceware.org/ml/crossgcc/2008-10/msg00068.html
            CT_DoLog DEBUG "Activating support for memset on broken ppc-8xx (CPU15 erratum)"
            extra_make_args+=( ASFLAGS="-DBROKEN_PPC_8xx_CPU15" )
            ;;
    esac

    CT_CFLAGS_FOR_BUILD+=" ${CT_EXTRA_CFLAGS_FOR_BUILD}"
    CT_LDFLAGS_FOR_BUILD+=" ${CT_EXTRA_LDFLAGS_FOR_BUILD}"
    extra_make_args+=( "BUILD_CFLAGS=${CT_CFLAGS_FOR_BUILD}" "BUILD_LDFLAGS=${CT_LDFLAGS_FOR_BUILD}" )

    case "$CT_BUILD" in
        *mingw*|*cygwin*|*msys*)
            # When installing headers on Cygwin, MSYS2 and MinGW-w64 sunrpc needs
            # gettext for building cross-rpcgen.
            extra_make_args+=( BUILD_CPPFLAGS="-I${CT_BUILDTOOLS_PREFIX_DIR}/include/" )
            extra_make_args+=( BUILD_LDFLAGS="-L${CT_BUILDTOOLS_PREFIX_DIR}/lib -Wl,-Bstatic -lintl -liconv -Wl,-Bdynamic" )
            ;;
        *darwin*)
            # .. and the same goes for Darwin.
            extra_make_args+=( BUILD_CPPFLAGS="-I${CT_BUILDTOOLS_PREFIX_DIR}/include/" )
            extra_make_args+=( BUILD_LDFLAGS="-L${CT_BUILDTOOLS_PREFIX_DIR}/lib -lintl" )
            ;;
    esac

    if [ "${libc_headers}" = "y" ]; then
        CT_DoLog EXTRA "Installing C library headers"

        # use the 'install-headers' makefile target to install the
        # headers
        CT_DoExecLog ALL ${make} ${JOBSFLAGS}                       \
                         install_root=${CT_SYSROOT_DIR}${extra_dir} \
                         install-bootstrap-headers=yes              \
                         "${extra_make_args[@]}"                    \
                         install-headers

        # For glibc, a few headers need to be manually installed
        if [ "${CT_LIBC}" = "glibc" ]; then
            # Two headers -- stubs.h and features.h -- aren't installed by install-headers,
            # so do them by hand.  We can tolerate an empty stubs.h for the moment.
            # See e.g. http://gcc.gnu.org/ml/gcc/2002-01/msg00900.html
            mkdir -p "${CT_HEADERS_DIR}/gnu"
            CT_DoExecLog ALL touch "${CT_HEADERS_DIR}/gnu/stubs.h"
            CT_DoExecLog ALL cp -v "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/include/features.h"  \
                                   "${CT_HEADERS_DIR}/features.h"

            # Building the bootstrap gcc requires either setting inhibit_libc, or
            # having a copy of stdio_lim.h... see
            # http://sources.redhat.com/ml/libc-alpha/2003-11/msg00045.html
            CT_DoExecLog ALL cp -v bits/stdio_lim.h "${CT_HEADERS_DIR}/bits/stdio_lim.h"

            # Following error building gcc-4.0.0's gcj:
            #  error: bits/syscall.h: No such file or directory
            # solved by following copy; see http://sourceware.org/ml/crossgcc/2005-05/msg00168.html
            # but it breaks arm, see http://sourceware.org/ml/crossgcc/2006-01/msg00091.html
            # Of course, only copy it if it does not already exist
            case "${CT_ARCH}" in
                arm)    ;;
                *)  if [ -f "${CT_HEADERS_DIR}/bits/syscall.h" ]; then
                        CT_DoLog ALL "Not over-writing existing bits/syscall.h"
                    elif [ -f "misc/bits/syscall.h" ]; then
                        CT_DoExecLog ALL cp -v "misc/bits/syscall.h"            \
                                               "${CT_HEADERS_DIR}/bits/syscall.h"
                    else
                        # "Old" glibces do not have the above file,
                        # but provide this one:
                        CT_DoExecLog ALL cp -v "misc/syscall-list.h"            \
                                               "${CT_HEADERS_DIR}/bits/syscall.h"
                    fi
                    ;;
            esac
        fi
    fi # libc_headers == y

    if [ "${libc_startfiles}" = "y" ]; then
        if [ "${CT_THREADS}" = "nptl" ]; then
            CT_DoLog EXTRA "Installing C library start files"

            # there are a few object files needed to link shared libraries,
            # which we build and install by hand
            CT_DoExecLog ALL mkdir -p "${CT_SYSROOT_DIR}${extra_dir}/usr/lib"
            CT_DoExecLog ALL ${make} ${JOBSFLAGS} \
                        "${extra_make_args[@]}"   \
                        csu/subdir_lib
            CT_DoExecLog ALL cp csu/crt1.o csu/crti.o csu/crtn.o    \
                                "${CT_SYSROOT_DIR}${extra_dir}/usr/lib"

            # Finally, 'libgcc_s.so' requires a 'libc.so' to link against.
            # However, since we will never actually execute its code,
            # it doesn't matter what it contains.  So, treating '/dev/null'
            # as a C source file, we produce a dummy 'libc.so' in one step
            CT_DoExecLog ALL "${cross_cc}" ${extra_flags}   \
                                           -nostdlib        \
                                           -nostartfiles    \
                                           -shared          \
                                           -x c /dev/null   \
                                           -o "${CT_SYSROOT_DIR}${extra_dir}/usr/lib/libc.so"
        fi # threads == nptl
    fi # libc_headers == y

    if [ "${libc_full}" = "y" ]; then
        CT_DoLog EXTRA "Building C library"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS}         \
                              "${extra_make_args[@]}" \
                              all

        CT_DoLog EXTRA "Installing C library"
        CT_DoExecLog ALL ${make} ${JOBSFLAGS}                               \
                              "${extra_make_args[@]}"                       \
                              install_root="${CT_SYSROOT_DIR}${extra_dir}"  \
                              install

        if [ "${CT_BUILD_MANUALS}" = "y" ]; then
            CT_DoLog EXTRA "Building and installing the C library manual"
            # Omit JOBSFLAGS as GLIBC has problems building the
            # manuals in parallel
            CT_DoExecLog ALL ${make} pdf html
            CT_DoExecLog ALL mkdir -p ${CT_PREFIX_DIR}/share/doc
            CT_DoExecLog ALL cp -av ${src_dir}/manual/*.pdf    \
                                    ${src_dir}/manual/libc     \
                                    ${CT_PREFIX_DIR}/share/doc
        fi

        if [ "${CT_LIBC_LOCALES}" = "y" ]; then
            do_libc_locales
        fi
    fi # libc_full == y
}

# Build up the addons list, separated with $1
do_libc_add_ons_list() {
    local sep="$1"
    local addons_list="$( echo "${CT_LIBC_ADDONS_LIST}"            \
                          |${sed} -r -e "s/[[:space:],]/${sep}/g;" \
                        )"
    if [ "${CT_LIBC_GLIBC_2_20_or_later}" != "y" ]; then
        case "${CT_THREADS}" in
            none)   ;;
            *)      addons_list="${addons_list}${sep}${CT_THREADS}";;
        esac
    fi
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && addons_list="${addons_list}${sep}ports"
    # Remove duplicate, leading and trailing separators
    echo "${addons_list}" |${sed} -r -e "s/${sep}+/${sep}/g; s/^${sep}//; s/${sep}\$//;"
}

# Compute up the minimum supported Linux kernel version
do_libc_min_kernel_config() {
    local min_kernel_config

    case "${CT_LIBC_GLIBC_EXTRA_CONFIG_ARRAY[*]}" in
        *--enable-kernel*) ;;
        *)  if [ "${CT_LIBC_GLIBC_KERNEL_VERSION_AS_HEADERS}" = "y" ]; then
                # We can't rely on the kernel version from the configuration,
                # because it might not be available if the user uses pre-installed
                # headers. On the other hand, both method will have the kernel
                # version installed in "usr/include/linux/version.h" in the sysroot.
                # Parse that instead of having two code-paths.
                version_code_file="${CT_SYSROOT_DIR}/usr/include/linux/version.h"
                if [ ! -f "${version_code_file}" -o ! -r "${version_code_file}" ]; then
                    CT_Abort "Linux version is unavailable in installed headers files"
                fi
                version_code="$(${grep} -E LINUX_VERSION_CODE "${version_code_file}"  \
                                 |cut -d' ' -f 3                                      \
                               )"
                version=$(((version_code>>16)&0xFF))
                patchlevel=$(((version_code>>8)&0xFF))
                sublevel=$((version_code&0xFF))
                min_kernel_config="${version}.${patchlevel}.${sublevel}"
            elif [ "${CT_LIBC_GLIBC_KERNEL_VERSION_CHOSEN}" = "y" ]; then
                # Trim the fourth part of the linux version, keeping only the first three numbers
                min_kernel_config="$( echo "${CT_LIBC_GLIBC_MIN_KERNEL_VERSION}"               \
                                      |${sed} -r -e 's/^([^.]+\.[^.]+\.[^.]+)(|\.[^.]+)$/\1/;' \
                                    )"
            fi
            echo "--enable-kernel=${min_kernel_config}"
            ;;
    esac
}

# Build and install the libc locales
do_libc_locales() {
    local src_dir="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}"
    local -a extra_config
    local glibc_cflags

    mkdir -p "${CT_BUILD_DIR}/build-localedef"
    cd "${CT_BUILD_DIR}/build-localedef"

    CT_DoLog EXTRA "Configuring C library localedef"

    # Versions that don't support --with-pkgversion or --with-bugurl will cause
    # a harmless: `configure: WARNING: unrecognized options: --with-bugurl...`
    # If it's set, use it, if is a recognized option.
    if [ ! "${CT_TOOLCHAIN_PKGVERSION}" = "" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    fi
    if [ ! "${CT_TOOLCHAIN_BUGURL}" = "" ]; then
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    CT_DoLog DEBUG "Extra config args passed: '${extra_config[*]}'"

    glibc_cflags="-O2 -fno-stack-protector"
    case "${CT_LIBC_ENABLE_FORTIFIED_BUILD}" in
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
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}

    # The target's endianness and uint32_t alignment should be passed as options
    # to localedef, but glibc's localedef does not support these options, which
    # means that the locale files generated here will be suitable for the target
    # only if it has the same endianness and uint32_t alignment as the host's.

    CT_DoLog EXTRA "Installing C library locales"
    CT_DoExecLog ALL ${make} ${JOBSFLAGS}                  \
                          install_root="${CT_SYSROOT_DIR}" \
                          localedata/install-locales
}

