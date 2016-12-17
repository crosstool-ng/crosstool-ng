# This file adds the function to build the gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download gcc
do_gcc_get() {
    local linaro_version=""
    local linaro_series=""

    if [ "${CT_CC_GCC_CUSTOM}" = "y" ]; then
        CT_GetCustom "gcc" "${CT_CC_GCC_CUSTOM_VERSION}" \
            "${CT_CC_GCC_CUSTOM_LOCATION}"
    else
        # Account for the Linaro versioning
        linaro_version="$( echo "${CT_CC_GCC_VERSION}"  \
                           |sed -r -e 's/^linaro-//;'   \
                         )"
        linaro_series="$( echo "${linaro_version}"      \
                          |sed -r -e 's/-.*//;'         \
                        )"

        # The official gcc hosts put gcc under a gcc/release/ directory,
        # whereas the mirrors put it in the gcc/ directory.
        # Also, Split out linaro mirrors, so that downloads happen faster.
        if [ x"${linaro_version}" = x"${CT_CC_GCC_VERSION}" ]; then
            CT_GetFile "gcc-${CT_CC_GCC_VERSION}"                                                   \
                       {http,ftp,https}://ftp.gnu.org/gnu/gcc/gcc-${CT_CC_GCC_VERSION} \
                       ftp://{gcc.gnu.org,sourceware.org}/pub/gcc/releases/gcc-${CT_CC_GCC_VERSION}
        else
            YYMM=`echo ${CT_CC_GCC_VERSION} |cut -d- -f3 |sed -e 's,^..,,'`
            CT_GetFile "gcc-${CT_CC_GCC_VERSION}"                                                             \
                       "https://releases.linaro.org/components/toolchain/gcc-linaro/${linaro_version}"        \
                       "https://releases.linaro.org/${YYMM}/components/toolchain/gcc-linaro/${linaro_series}" \
                       "http://launchpad.net/gcc-linaro/${linaro_series}/${linaro_version}/+download"         \
                       http://cbuild.validation.linaro.org/snapshots
        fi

    fi # ! custom location
    # Starting with GCC 4.3, ecj is used for Java, and will only be
    # built if the configure script finds ecj.jar at the top of the
    # GCC source tree, which will not be there unless we get it and
    # put it there ourselves
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y" ]; then
        CT_GetFile ecj-latest .jar http://mirrors.kernel.org/sourceware/java/ \
                                   http://crosstool-ng.org/pub/java           \
                                   ftp://gcc.gnu.org/pub/java                 \
                                   ftp://sourceware.org/pub/java
    fi
}

# Extract gcc
do_gcc_extract() {
    CT_Extract "gcc-${CT_CC_GCC_VERSION}"
    CT_Patch "gcc" "${CT_CC_GCC_VERSION}"

    # Copy ecj-latest.jar to ecj.jar at the top of the GCC source tree
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y"                     \
         -a ! -f "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/ecj.jar"   \
       ]; then
        CT_DoExecLog ALL cp -v "${CT_TARBALLS_DIR}/ecj-latest.jar" "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/ecj.jar"
    fi

    if [ -n "${CT_ARCH_XTENSA_CUSTOM_NAME}" ]; then
        CT_ConfigureXtensa "gcc" "${CT_CC_GCC_VERSION}"
    fi
}

#------------------------------------------------------------------------------
# This function builds up the set of languages to enable
# No argument expected, returns the comma-separated language list on stdout
cc_gcc_lang_list() {
    local lang_list

    lang_list="c"
    [ "${CT_CC_LANG_CXX}" = "y"      ] && lang_list+=",c++"
    [ "${CT_CC_LANG_FORTRAN}" = "y"  ] && lang_list+=",fortran"
    [ "${CT_CC_LANG_ADA}" = "y"      ] && lang_list+=",ada"
    [ "${CT_CC_LANG_JAVA}" = "y"     ] && lang_list+=",java"
    [ "${CT_CC_LANG_OBJC}" = "y"     ] && lang_list+=",objc"
    [ "${CT_CC_LANG_OBJCXX}" = "y"   ] && lang_list+=",obj-c++"
    [ "${CT_CC_LANG_GOLANG}" = "y"   ] && lang_list+=",go"
    lang_list+="${CT_CC_LANG_OTHERS:+,${CT_CC_LANG_OTHERS}}"

    printf "%s" "${lang_list}"
}

#------------------------------------------------------------------------------
# Return a value of a requested GCC spec
cc_gcc_get_spec() {
    local spec=$1
    local cc_and_cflags=$2

    # GCC does not provide a facility to request a value of a spec string.
    # The only way to do that I found was to augment the spec file with
    # some dummy suffix handler that does nothing except printing it.
    touch temp-input.spec_eval
    {
        echo ".spec_eval:"
        echo "echo %(${spec})"
    } > "tmp-specs-${spec}"
    ${cc_and_cflags} -specs="tmp-specs-${spec}" -E temp-input.spec_eval
}

#------------------------------------------------------------------------------
# Report the type of a GCC option
cc_gcc_classify_opt() {
    # Options present in multiple architectures
    case "${1}" in
        -march=*) echo "arch"; return;;
        -mabi=*) echo "abi"; return;;
        -mcpu=*|-mmcu=*) echo "cpu"; return;;
        -mtune=*) echo "tune"; return;;
        -mfpu=*) echo "fpu"; return;;
        -mhard-float|-msoft-float|-mno-soft-float|-mno-float|-mfloat-abi=*|\
            -mfpu|-mno-fpu) echo "float"; return;;
        -EB|-EL|-mbig-endian|-mlittle-endian|-mbig|-mlittle|-meb|-mel|-mb|-ml) echo "endian"; return;;
        -mthumb|-marm) echo "mode"; return;;
    esac

    # Arch-specific options and aliases
    case "${CT_ARCH}" in
        m68k)
            case "${1}" in
                -m68881) echo "float"; return;;
                -m5[234]*|-mcfv4e) echo "cpu"; return;;
                -m68*|-mc68*) echo "arch"; return;;
            esac
            ;;
        mips)
            case "${1}" in
                -mips[1234]|-mips32|-mips32r*|-mips64|-mips64r*) echo "cpu"; return;;
            esac
            ;;
        sh)
            case "${1}" in
                -m[12345]*) echo "cpu"; return;;
            esac
    esac

    # All tried and failed
    echo "unknown"
}

#------------------------------------------------------------------------------
# This function lists the multilibs configured in the compiler (even if multilib
# is disabled - so that it lists the default GCC/OS directory, which may differ
# from the default 'lib'). It then performs a few multilib checks/quirks:
#
# 1. On SuperH target, configuring with default CPU (e.g. by supplying the target
# name as 'sh4', which is what CT-NG does) results in the compiler being unable to
# run if that same switch is passed to the resulting gcc (e.g. 'gcc -m4'). The reason
# for this behavior is that the script that determines the sysroot suffix is not
# aware of the default multilib selection, so it generates <sysroot>/m4 as the
# suffixed sysroot. But the main driver, knowing that -m4 is the default, does not
# even attempt to fall back to the non-suffixed sysroot (as it does with non-default
# multilibs) - as a result, gcc fails to find any library if invoked with -m4.
# The right solution would be to drop the default CPU from the multilib list
# completely, or make the print-sysroot-suffix.sh script aware of the defaults
# (which is not easy, as the defaults are not in tmake_file, but rather in tm_file...)
#
# 2. On MIPS target, gcc (or rather, ld, which it invokes under the hood) chokes
# if supplied with two -mabi=* options. I.e., 'gcc -mabi=n32' and 'gcc -mabi=32' both
# work, but 'gcc -mabi=32 -mabi=n32' produces an internal error in ld. Thus we do
# not supply target's CFLAGS in multilib builds - and after compiling pass-1 gcc,
# attempt to determine which CFLAGS need to be filtered out.
cc_gcc_multilib_housekeeping() {
    local cc host
    local flags osdir dir multilibs i f
    local multilib_defaults
    local suffix sysroot base lnk
    local ml_arch ml_abi ml_cpu ml_tune ml_fpu ml_float ml_endian ml_mode ml_unknown ml
    local new_cflags

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    if [ \( "${CT_CANADIAN}" = "y" -o "${CT_CROSS_NATIVE}" = "y" \) -a "${host}" = "${CT_HOST}" ]; then
        CT_DoLog EXTRA "Canadian Cross/Cross-native unable to confirm multilibs configuration "\
            "directly; will use build-compiler for housekeeping."
        # Since we cannot run the desired compiler, substitute build-CC with the assumption
        # that the host-CC is configured in the same way.
        cc="${CT_BUILDTOOLS_PREFIX_DIR}/bin/${CT_TARGET}-gcc"
    fi

    # sed: prepend dashes or do nothing if default is empty string
    multilib_defaults=( $( cc_gcc_get_spec multilib_defaults "${cc}" | \
        sed 's/\(^\|[[:space:]]\+\)\([^[:space:]]\)/ -\2/g' ) )
    CT_DoLog EXTRA "gcc default flags: '${multilib_defaults}'"

    multilibs=( $( "${cc}" -print-multi-lib ) )
    if [ ${#multilibs[@]} -ne 0 ]; then
        CT_DoLog EXTRA "gcc configured with these multilibs (including the default):"
        for i in "${multilibs[@]}"; do
            dir="lib/${i%%;*}"
            flags="${i#*;}"
            flags=${flags//@/ -}
            flags=$( echo ${flags} )
            osdir="lib/"$( "${cc}" -print-multi-os-directory ${flags} )
            CT_SanitizeVarDir dir osdir
            CT_DoLog EXTRA "   '${flags}' --> ${dir} (gcc)   ${osdir} (os)"
            for f in ${flags}; do
                eval ml_`cc_gcc_classify_opt ${f}`=seen
            done
        done
    else
        CT_DoLog WARN "no multilib configuration: GCC unusable?"
    fi

    # Filtering out some of the options provided in CT-NG config. Then *prepend*
    # them to CT_TARGET_CFLAGS, like scripts/crosstool-NG.sh does. Zero out
    # the stashed MULTILIB flags so that we don't process them again in the passes
    # that follow.
    CT_DoLog DEBUG "Configured target CFLAGS: '${CT_ARCH_TARGET_CFLAGS_MULTILIB}'"
    ml_unknown= # Pass through anything we don't know about
    for f in ${CT_ARCH_TARGET_CFLAGS_MULTILIB}; do
        eval ml=\$ml_`cc_gcc_classify_opt ${f}`
        if [ "${ml}" != "seen" ]; then
            new_cflags="${new_cflags} ${f}"
        fi
    done
    CT_DoLog DEBUG "Filtered target CFLAGS: '${new_cflags}'"
    CT_EnvModify CT_TARGET_CFLAGS "${new_cflags} ${CT_TARGET_CFLAGS}"
    CT_EnvModify CT_ARCH_TARGET_CFLAGS_MULTILIB ""

    # Currently, the only LDFLAGS are endianness-related
    CT_DoLog DEBUG "Configured target LDFLAGS: '${CT_ARCH_TARGET_LDFLAGS_MULTILIB}'"
    if [ "${ml_endian}" != "seen" ]; then
        CT_EnvModify CT_TARGET_LDFLAGS "${CT_ARCH_TARGET_LDFLAGS_MULTILIB} ${CT_TARGET_LDFLAGS}"
        CT_EnvModify CT_ARCH_TARGET_LDFLAGS_MULTILIB ""
    fi
    CT_DoLog DEBUG "Filtered target LDFLAGS: '${CT_ARCH_TARGET_LDFLAGS_MULTILIB}'"

    # Sysroot suffix fixup for the multilib default.
    suffix=$( cc_gcc_get_spec sysroot_suffix_spec "${cc} ${multilib_defaults}" )
    if [ -n "${suffix}" ]; then
        base=${suffix%/*}
        sysroot=$( "${cc}" -print-sysroot )
        if [ -n "${base}" ]; then
            CT_DoExecLog ALL mkdir -p "${sysroot}${base}"
            lnk=$( echo "${base#/}" | sed -e 's,[^/]*,..,g' )
        else
            lnk=.
        fi
        CT_DoExecLog ALL rm -f "${sysroot}${suffix}"
        CT_DoExecLog ALL ln -sfv "${lnk}" "${sysroot}${suffix}"
    fi
}

#------------------------------------------------------------------------------
# Core gcc pass 1
do_gcc_core_pass_1() {
    local -a core_opts

    if [ "${CT_CC_CORE_PASS_1_NEEDED}" != "y" ]; then
        return 0
    fi

    core_opts+=( "mode=static" )
    core_opts+=( "host=${CT_BUILD}" )
    core_opts+=( "complibs=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    core_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    core_opts+=( "lang_list=c" )
    core_opts+=( "build_step=core1" )

    CT_DoStep INFO "Installing pass-1 core C gcc compiler"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-core-pass-1"

    do_gcc_core_backend "${core_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Core gcc pass 2
do_gcc_core_pass_2() {
    local -a core_opts

    if [ "${CT_CC_CORE_PASS_2_NEEDED}" != "y" ]; then
        return 0
    fi

    # Common options:
    core_opts+=( "host=${CT_BUILD}" )
    core_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "complibs=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    core_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    core_opts+=( "lang_list=c" )
    core_opts+=( "build_step=core2" )

    # Different conditions are at stake here:
    #   - In case the threading model is NPTL, we need a shared-capable core
    #     gcc; in all other cases, we need a static-only core gcc.
    #   - In case the threading model is NPTL or win32, or gcc is 4.3 or
    #     later, we need to build libgcc
    case "${CT_THREADS}" in
        nptl)
            core_opts+=( "mode=shared" )
            core_opts+=( "build_libgcc=yes" )
            ;;
        win32)
            core_opts+=( "mode=static" )
            core_opts+=( "build_libgcc=yes" )
            ;;
        *)
            core_opts+=( "mode=static" )
            core_opts+=( "build_libgcc=yes" )
            ;;
    esac

    CT_DoStep INFO "Installing pass-2 core C gcc compiler"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-core-pass-2"

    do_gcc_core_backend "${core_opts[@]}"

    CT_Popd
    CT_EndStep
}

#------------------------------------------------------------------------------
# Build core gcc
# This function is used to build the core C compiler.
# Usage: do_gcc_core_backend param=value [...]
#   Parameter           : Definition                                : Type      : Default
#   mode                : build a 'static', 'shared' or 'baremetal' : string    : (none)
#   host                : the machine the core will run on          : tuple     : (none)
#   prefix              : dir prefix to install into                : dir       : (none)
#   complibs            : dir where complibs are installed          : dir       : (none)
#   lang_list           : the list of languages to build            : string    : (empty)
#   build_libgcc        : build libgcc or not                       : bool      : no
#   build_libstdcxx     : build libstdc++ or not                    : bool      : no
#   build_libgfortran   : build libgfortran or not                  : bool      : no
#   build_staticlinked  : build statically linked or not            : bool      : no
#   build_manuals       : whether to build manuals or not           : bool      : no
#   cflags              : cflags to use                             : string    : (empty)
#   ldflags             : ldflags to use                            : string    : (empty)
#   build_step          : build step 'core1', 'core2', 'gcc_build'
#                         or 'gcc_host'                             : string    : (none)
# Usage: do_gcc_core_backend mode=[static|shared|baremetal] build_libgcc=[yes|no] build_staticlinked=[yes|no]
do_gcc_core_backend() {
    local mode
    local build_libgcc=no
    local build_libstdcxx=no
    local build_libgfortran=no
    local build_staticlinked=no
    local build_manuals=no
    local host
    local prefix
    local complibs
    local lang_list
    local cflags
    local ldflags
    local build_step
    local log_txt
    local tmp
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a core_LDFLAGS
    local -a core_targets
    local -a core_targets_all
    local -a core_targets_install
    local -a extra_user_config
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # This function gets called in case of a bare metal compiler for the final gcc, too.
    case "${build_step}" in
        core1|core2)
            CT_DoLog EXTRA "Configuring core C gcc compiler"
            log_txt="gcc"
            extra_user_config=( "${CT_CC_GCC_CORE_EXTRA_CONFIG_ARRAY[@]}" )
            ;;
        gcc_build|gcc_host)
            CT_DoLog EXTRA "Configuring final gcc compiler"
            extra_user_config=( "${CT_CC_GCC_EXTRA_CONFIG_ARRAY[@]}" )
            log_txt="final gcc compiler"
            if [ "${CT_CC_GCC_TARGET_FINAL}" = "y" ]; then
                # to inhibit the libiberty and libgcc tricks later on
                build_libgcc=no
            fi
            ;;
        *)
            CT_Abort "Internal Error: 'build_step' must be one of: 'core1', 'core2', 'gcc_build' or 'gcc_host', not '${build_step:-(empty)}'"
            ;;
    esac

    case "${mode}" in
        static)
            extra_config+=("--with-newlib")
            extra_config+=("--enable-threads=no")
            extra_config+=("--disable-shared")
            ;;
        shared)
            extra_config+=("--enable-shared")
            ;;
        baremetal)
            extra_config+=("--with-newlib")
            extra_config+=("--enable-threads=no")
            extra_config+=("--disable-shared")
            ;;
        *)
            CT_Abort "Internal Error: 'mode' must be one of: 'static', 'shared' or 'baremetal', not '${mode:-(empty)}'"
            ;;
    esac

    CT_DoLog DEBUG "Copying headers to install area of core C compiler"
    CT_DoExecLog ALL cp -a "${CT_HEADERS_DIR}" "${prefix}/${CT_TARGET}/include"

    for tmp in ARCH ABI CPU TUNE FPU FLOAT; do
        eval tmp="\${CT_ARCH_WITH_${tmp}}"
        if [ -n "${tmp}" ]; then
            extra_config+=("${tmp}")
        fi
    done

    if [ "${CT_CC_GCC_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config+=("--enable-__cxa_atexit")
    else
        extra_config+=("--disable-__cxa_atexit")
    fi

    if [ -n "${CT_CC_GCC_ENABLE_CXX_FLAGS}" \
            -a "${mode}" = "baremetal" ]; then
        extra_config+=("--enable-cxx-flags=${CT_CC_GCC_ENABLE_CXX_FLAGS}")
    fi

    extra_config+=(--disable-libgomp)
    extra_config+=(--disable-libmudflap)
    extra_config+=(--disable-libmpx)

    if [ "${CT_CC_GCC_LIBSSP}" = "y" ]; then
        extra_config+=(--enable-libssp)
    else
        extra_config+=(--disable-libssp)
    fi
    if [ "${CT_CC_GCC_HAS_LIBQUADMATH}" = "y" ]; then
        if [ "${CT_CC_GCC_LIBQUADMATH}" = "y" ]; then
            extra_config+=(--enable-libquadmath)
            extra_config+=(--enable-libquadmath-support)
        else
            extra_config+=(--disable-libquadmath)
            extra_config+=(--disable-libquadmath-support)
        fi
    fi

    core_LDFLAGS+=("${ldflags}")

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_gcc_backend, below.
    if [ "${build_staticlinked}" = "yes" ]; then
        core_LDFLAGS+=("-static")
        host_libstdcxx_flags+=("-static-libgcc")
        host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++")
        host_libstdcxx_flags+=("-lm")
        # Companion libraries are build static (eg !shared), so
        # the libstdc++ is not pulled automatically, although it
        # is needed. Shoe-horn it in our LDFLAGS
        # Ditto libm on some Fedora boxen
        core_LDFLAGS+=("-lstdc++")
        core_LDFLAGS+=("-lm")
    else
        if [ "${CT_CC_GCC_STATIC_LIBSTDCXX}" = "y" ]; then
            # this is from CodeSourcery arm-2010q1-202-arm-none-linux-gnueabi.src.tar.bz2
            # build script
            # INFO: if the host gcc is gcc-4.5 then presumably we could use -static-libstdc++,
            #       see http://gcc.gnu.org/ml/gcc-patches/2009-06/msg01635.html
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++,-Bdynamic")
            host_libstdcxx_flags+=("-lm")
        elif [ "${CT_COMPLIBS_SHARED}" != "y" ]; then
            # When companion libraries are build static (eg !shared),
            # the libstdc++ is not pulled automatically, although it
            # is needed. Shoe-horn it in our LDFLAGS
            # Ditto libm on some Fedora boxen
            core_LDFLAGS+=("-lstdc++")
            core_LDFLAGS+=("-lm")
        fi
    fi

    if [ "${CT_CC_GCC_USE_GMP_MPFR}" = "y" ]; then
        extra_config+=("--with-gmp=${complibs}")
        extra_config+=("--with-mpfr=${complibs}")
    fi
    if [ "${CT_CC_GCC_USE_MPC}" = "y" ]; then
        extra_config+=("--with-mpc=${complibs}")
    fi
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        if [ "${CT_ISL}" = "y" ]; then
            extra_config+=("--with-isl=${complibs}")
        fi
        if [ "${CT_CLOOG}" = "y" ]; then
            extra_config+=("--with-cloog=${complibs}")
        fi
    elif [ "${CT_CC_GCC_HAS_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-isl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--enable-lto")
    elif [ "${CT_CC_GCC_HAS_LTO}" = "y" ]; then
        extra_config+=("--disable-lto")
    fi

    if [ ${#host_libstdcxx_flags[@]} -ne 0 ]; then
        extra_config+=("--with-host-libstdcxx=${host_libstdcxx_flags[*]}")
    fi

    if [ "${CT_CC_GCC_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
        extra_config+=("--enable-target-optspace")
    fi
    if [ "${CT_CC_GCC_DISABLE_PCH}" = "y" ]; then
        extra_config+=("--disable-libstdcxx-pch")
    fi

    case "${CT_CC_GCC_LDBL_128}" in
        y)  extra_config+=("--with-long-double-128");;
        m)  ;;
        "") extra_config+=("--without-long-double-128");;
    esac

    if [ "${CT_CC_GCC_BUILD_ID}" = "y" ]; then
        extra_config+=( --enable-linker-build-id )
    fi

    case "${CT_CC_GCC_LNK_HASH_STYLE}" in
        "") ;;
        *)  extra_config+=( "--with-linker-hash-style=${CT_CC_GCC_LNK_HASH_STYLE}" );;
    esac

    case "${CT_CC_GCC_DEC_FLOATS}" in
        "") ;;
        *)  extra_config+=( "--enable-decimal-float=${CT_CC_GCC_DEC_FLOATS}" );;
    esac

    case "${CT_ARCH}" in
        mips)
            case "${CT_CC_GCC_mips_llsc}" in
                y)  extra_config+=( --with-llsc );;
                m)  ;;
                *)  extra_config+=( --without-llsc );;
            esac
            case "${CT_CC_GCC_mips_synci}" in
                y)  extra_config+=( --with-synci );;
                m)  ;;
                *)  extra_config+=( --without-synci );;
            esac
            if [ "${CT_CC_GCC_mips_plt}" ]; then
                extra_config+=( --with-mips-plt )
            fi
            ;; # ARCH is mips
    esac

    [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

    if [ "${CT_CC_GCC_SYSTEM_ZLIB}" = "y" ]; then
        extra_config+=("--with-system-zlib")
    fi

    # Some versions of gcc have a defective --enable-multilib.
    # Since that's the default, only pass --disable-multilib. For multilib,
    # also enable multiarch. Without explicit --enable-multiarch, pass-1
    # compiler is configured as multilib/no-multiarch and pass-2/final
    # are multilib/multiarch (because gcc autodetects multiarch based on
    # multiple instances of crt*.o in the install directory - which do
    # not exist in pass-1).
    if [ "${CT_MULTILIB}" != "y" ]; then
        extra_config+=("--disable-multilib")
    else
        extra_config+=("--enable-multiarch")
        if [ -n "${CT_CC_GCC_MULTILIB_LIST}" ]; then
            extra_config+=("--with-multilib-list=${CT_CC_GCC_MULTILIB_LIST}")
        fi
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # Clang's default bracket-depth is 256, and building GCC
    # requires somewhere between 257 and 512.
    if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
        cflags="$cflags "-fbracket-depth=512
    fi

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532)
    CT_DoExecLog CFG                                   \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                     \
    CFLAGS="${cflags}"                                 \
    CXXFLAGS="${cflags}"                               \
    LDFLAGS="${core_LDFLAGS[*]}"                       \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"            \
    CXXFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"          \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"          \
    "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/configure" \
        --build=${CT_BUILD}                            \
        --host=${host}                                 \
        --target=${CT_TARGET}                          \
        --prefix="${prefix}"                           \
        --with-local-prefix="${CT_SYSROOT_DIR}"        \
        ${CC_CORE_SYSROOT_ARG}                         \
        "${extra_config[@]}"                           \
        --enable-languages="${lang_list}"              \
        "${extra_user_config[@]}"

    if [ "${build_libgcc}" = "yes" ]; then
        # HACK: we need to override SHLIB_LC from gcc/config/t-slibgcc-elf-ver or
        # gcc/config/t-libunwind so -lc is removed from the link for
        # libgcc_s.so, as we do not have a target -lc yet.
        # This is not as ugly as it appears to be ;-) All symbols get resolved
        # during the glibc build, and we provide a proper libgcc_s.so for the
        # cross toolchain during the final gcc build.
        #
        # As we cannot modify the source tree, nor override SHLIB_LC itself
        # during configure or make, we have to edit the resultant
        # gcc/libgcc.mk itself to remove -lc from the link.
        # This causes us to have to jump through some hoops...
        #
        # To produce libgcc.mk to edit we firstly require libiberty.a,
        # so we configure then build it.
        # Next we have to configure gcc, create libgcc.mk then edit it...
        # So much easier if we just edit the source tree, but hey...
        if [ ! -f "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/gcc/BASE-VER" ]; then
            CT_DoExecLog CFG make ${JOBSFLAGS} configure-libiberty
            CT_DoExecLog ALL make ${JOBSFLAGS} -C libiberty libiberty.a
            CT_DoExecLog CFG make ${JOBSFLAGS} configure-gcc configure-libcpp
            CT_DoExecLog ALL make ${JOBSFLAGS} all-libcpp
        else
            CT_DoExecLog CFG make ${JOBSFLAGS} configure-gcc configure-libcpp configure-build-libiberty
            CT_DoExecLog ALL make ${JOBSFLAGS} all-libcpp all-build-libiberty
        fi
        # HACK: gcc-4.2 uses libdecnumber to build libgcc.mk, so build it here.
        if [ -d "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/libdecnumber" ]; then
            CT_DoExecLog CFG make ${JOBSFLAGS} configure-libdecnumber
            CT_DoExecLog ALL make ${JOBSFLAGS} -C libdecnumber libdecnumber.a
        fi
        # HACK: gcc-4.8 uses libbacktrace to make libgcc.mvars, so make it here.
        if [ -d "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/libbacktrace" ]; then
            CT_DoExecLog CFG make ${JOBSFLAGS} configure-libbacktrace
            CT_DoExecLog ALL make ${JOBSFLAGS} -C libbacktrace
        fi

        libgcc_rule="libgcc.mvars"
        core_targets=( gcc target-libgcc )

        # On bare metal and canadian build the host-compiler is used when
        # actually the build-system compiler is required. Choose the correct
        # compilers for canadian build and use the defaults on other
        # configurations.
        if [ "${CT_BARE_METAL},${CT_CANADIAN}" = "y,y" ]; then
            repair_cc="CC_FOR_BUILD=${CT_BUILD}-gcc \
                       CXX_FOR_BUILD=${CT_BUILD}-g++ \
                       GCC_FOR_TARGET=${CT_TARGET}-gcc"
        else
            repair_cc=""
        fi

        CT_DoExecLog ALL make ${JOBSFLAGS} -C gcc ${libgcc_rule} \
                              ${repair_cc}
        sed -r -i -e 's@-lc@@g' gcc/${libgcc_rule}
    else # build_libgcc
        core_targets=( gcc )
    fi   # ! build libgcc
    if [    "${build_libstdcxx}" = "yes"    \
         -a "${CT_CC_LANG_CXX}"  = "y"      \
       ]; then
        core_targets+=( target-libstdc++-v3 )
    fi

    if [    "${build_libgfortran}" = "yes"    \
         -a "${CT_CC_LANG_FORTRAN}"  = "y"    \
       ]; then
        core_targets+=( target-libgfortran )
    fi

    core_targets_all="${core_targets[@]/#/all-}"
    core_targets_install="${core_targets[@]/#/install-}"

    case "${build_step}" in
        gcc_build|gcc_host)
            if [ "${CT_CC_GCC_TARGET_FINAL}" = "y" ]; then
                core_targets_all=all
                core_targets_install=install
            fi
            ;;
    esac

    CT_DoLog EXTRA "Building ${log_txt}"
    CT_DoExecLog ALL make ${JOBSFLAGS} ${core_targets_all}

    # Do not pass ${JOBSFLAGS} here: recent GCC builds have been failing
    # in parallel 'make install' at random locations: libitm, libcilk,
    # always for the files that are installed more than once to the same
    # location (such as libitm.info).
    # The symptom is that the install command fails with "File exists"
    # error; running the same command manually succeeds. It looks like
    # attempts to remove the destination and re-create it, but another
    # install gets in the way.
    CT_DoLog EXTRA "Installing ${log_txt}"
    CT_DoExecLog ALL make ${core_targets_install}

    # Remove the libtool "pseudo-libraries": having them in the installed
    # tree makes the libtoolized utilities that are built next assume
    # that, for example, libsupc++ is an "accessory library", and not include
    # -lsupc++ to the link flags. That breaks ltrace, for example.
    CT_DoLog EXTRA "Housekeeping for core gcc compiler"
    CT_Pushd "${prefix}"
    find . -type f -name "*.la" -exec rm {} \; |CT_DoLog ALL
    CT_Popd

    if [ "${build_manuals}" = "yes" ]; then
        CT_DoLog EXTRA "Building the GCC manuals"
        CT_DoExecLog ALL make pdf html
        CT_DoLog EXTRA "Installing the GCC manuals"
        CT_DoExecLog ALL make install-{pdf,html}-gcc
    fi

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-gcc to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${prefix}/bin/${CT_TARGET}-gcc."* 2>/dev/null || true )"
    [ -z "${file}" ] || ext=".${file##*.}"
    if [ -f "${prefix}/bin/${CT_TARGET}-gcc${ext}" ]; then
        CT_DoExecLog ALL ln -sfv "${CT_TARGET}-gcc${ext}" "${prefix}/bin/${CT_TARGET}-cc${ext}"
    fi

    cc_gcc_multilib_housekeeping cc="${prefix}/bin/${CT_TARGET}-gcc" \
        host="${host}"
}

#------------------------------------------------------------------------------
# Build complete gcc to run on build
do_gcc_for_build() {
    local -a build_final_opts
    local build_final_backend

    # If native or simple cross toolchain is being built, then build==host;
    # nothing to do.
    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    build_final_opts+=( "host=${CT_BUILD}" )
    build_final_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    build_final_opts+=( "complibs=${CT_BUILDTOOLS_PREFIX_DIR}" )
    build_final_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    build_final_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    build_final_opts+=( "lang_list=$( cc_gcc_lang_list )" )
    build_final_opts+=( "build_step=gcc_build" )
    if [ "${CT_BARE_METAL}" = "y" ]; then
        # In the tests I've done, bare-metal was not impacted by the
        # lack of such a compiler, but better safe than sorry...
        build_final_opts+=( "mode=baremetal" )
        build_final_opts+=( "build_libgcc=yes" )
        build_final_opts+=( "build_libstdcxx=yes" )
        build_final_opts+=( "build_libgfortran=yes" )
        if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
            build_final_opts+=( "build_staticlinked=yes" )
        fi
        build_final_backend=do_gcc_core_backend
    else
        build_final_backend=do_gcc_backend
    fi

    CT_DoStep INFO "Installing final gcc compiler for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-final-build-${CT_BUILD}"

    "${build_final_backend}" "${build_final_opts[@]}"

    CT_Popd
    CT_EndStep
}

gcc_movelibs() {
    local multi_flags multi_dir multi_os_dir multi_root multi_index multi_count
    local gcc_dir

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # Move only files, directories are for other multilibs. We're looking inside
    # GCC's directory structure, thus use unmangled multi_os_dir that GCC reports.
    gcc_dir="${CT_PREFIX_DIR}/${CT_TARGET}/lib/${multi_os_dir_gcc}"
    if [ ! -d "${gcc_dir}" ]; then
        # GCC didn't install anything outside of sysroot
        return
    fi
    ls "${gcc_dir}" | while read f; do
        case "${f}" in
            *.ld)
                # Linker scripts remain in GCC's directory; elf2flt insists on
                # finding them there.
                continue
                ;;
        esac
        if [ -f "${gcc_dir}/${f}" ]; then
            CT_DoExecLog ALL mkdir -p "${multi_root}/lib/${multi_os_dir}"
            CT_DoExecLog ALL mv "${gcc_dir}/${f}" "${multi_root}/lib/${multi_os_dir}/${f}"
        fi
    done
}

#------------------------------------------------------------------------------
# Build final gcc to run on host
do_gcc_for_host() {
    local -a final_opts
    local final_backend

    final_opts+=( "host=${CT_HOST}" )
    final_opts+=( "prefix=${CT_PREFIX_DIR}" )
    final_opts+=( "complibs=${CT_HOST_COMPLIBS_DIR}" )
    final_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    final_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    final_opts+=( "lang_list=$( cc_gcc_lang_list )" )
    final_opts+=( "build_step=gcc_host" )
    if [ "${CT_BUILD_MANUALS}" = "y" ]; then
        final_opts+=( "build_manuals=yes" )
    fi
    if [ "${CT_BARE_METAL}" = "y" ]; then
        final_opts+=( "mode=baremetal" )
        final_opts+=( "build_libgcc=yes" )
        final_opts+=( "build_libstdcxx=yes" )
        final_opts+=( "build_libgfortran=yes" )
        if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
            final_opts+=( "build_staticlinked=yes" )
        fi
        final_backend=do_gcc_core_backend
    else
        final_backend=do_gcc_backend
    fi

    CT_DoStep INFO "Installing final gcc compiler"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-final"
    "${final_backend}" "${final_opts[@]}"
    CT_Popd

    # GCC installs stuff (including libgcc) into its own /lib dir,
    # outside of sysroot, breaking linking with -static-libgcc.
    # Fix up by moving the libraries into the sysroot.
    if [ "${CT_USE_SYSROOT}" = "y" ]; then
        CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-final-movelibs"
        CT_IterateMultilibs gcc_movelibs movelibs
        CT_Popd
    fi

    CT_EndStep
}

#------------------------------------------------------------------------------
# Build the final gcc
# Usage: do_gcc_backend param=value [...]
#   Parameter     : Definition                          : Type      : Default
#   host          : the host we run onto                : tuple     : (none)
#   prefix        : the runtime prefix                  : dir       : (none)
#   complibs      : the companion libraries prefix      : dir       : (none)
#   cflags        : cflags to use                       : string    : (empty)
#   ldflags       : ldflags to use                      : string    : (empty)
#   lang_list     : the list of languages to build      : string    : (empty)
#   build_manuals : whether to build manuals or not     : bool      : no
do_gcc_backend() {
    local host
    local prefix
    local complibs
    local lang_list
    local cflags
    local ldflags
    local build_manuals
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a final_LDFLAGS
    local tmp
    local arg

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    CT_DoLog EXTRA "Configuring final gcc compiler"

    # Enable selected languages
    extra_config+=("--enable-languages=${lang_list}")

    for tmp in ARCH ABI CPU TUNE FPU FLOAT; do
        eval tmp="\${CT_ARCH_WITH_${tmp}}"
        if [ -n "${tmp}" ]; then
            extra_config+=("${tmp}")
        fi
    done

    [ "${CT_SHARED_LIBS}" = "y" ] || extra_config+=("--disable-shared")
    if [ "${CT_CC_GCC_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi
    case "${CT_CC_GCC_SJLJ_EXCEPTIONS}" in
        y)  extra_config+=("--enable-sjlj-exceptions");;
        m)  ;;
        "") extra_config+=("--disable-sjlj-exceptions");;
    esac
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config+=("--enable-__cxa_atexit")
    else
        extra_config+=("--disable-__cxa_atexit")
    fi

    if [ -n "${CT_CC_GCC_ENABLE_CXX_FLAGS}" ]; then
        extra_config+=("--enable-cxx-flags=${CT_CC_GCC_ENABLE_CXX_FLAGS}")
    fi

    if [ "${CT_THREADS}" = "none" ]; then
        extra_config+=(--disable-libatomic)
    fi
    if [ "${CT_CC_GCC_LIBMUDFLAP}" = "y" ]; then
        extra_config+=(--enable-libmudflap)
    else
        extra_config+=(--disable-libmudflap)
    fi
    if [ "${CT_CC_GCC_LIBGOMP}" = "y" ]; then
        extra_config+=(--enable-libgomp)
    else
        extra_config+=(--disable-libgomp)
    fi
    if [ "${CT_CC_GCC_LIBSSP}" = "y" ]; then
        extra_config+=(--enable-libssp)
    else
        extra_config+=(--disable-libssp)
    fi
    if [ "${CT_CC_GCC_HAS_LIBQUADMATH}" = "y" ]; then
        if [ "${CT_CC_GCC_LIBQUADMATH}" = "y" ]; then
            extra_config+=(--enable-libquadmath)
            extra_config+=(--enable-libquadmath-support)
        else
            extra_config+=(--disable-libquadmath)
            extra_config+=(--disable-libquadmath-support)
        fi
    fi

    if [ "${CT_CC_GCC_HAS_LIBSANITIZER}" = "y" ]; then
        if [ "${CT_CC_GCC_LIBSANITIZER}" = "y" ]; then
            extra_config+=(--enable-libsanitizer)
        else
            extra_config+=(--disable-libsanitizer)
        fi
    fi

    if [ "${CT_CC_GCC_HAS_LIBMPX}" = "y" ]; then
        if [ "${CT_CC_GCC_LIBMPX}" = "y" ]; then
            extra_config+=(--enable-libmpx)
        else
            extra_config+=(--disable-libmpx)
        fi
    fi

    final_LDFLAGS+=("${ldflags}")

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_gcc_core_backend, above.
    if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
        final_LDFLAGS+=("-static")
        host_libstdcxx_flags+=("-static-libgcc")
        host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++")
        host_libstdcxx_flags+=("-lm")
        # Companion libraries are build static (eg !shared), so
        # the libstdc++ is not pulled automatically, although it
        # is needed. Shoe-horn it in our LDFLAGS
        # Ditto libm on some Fedora boxen
        final_LDFLAGS+=("-lstdc++")
        final_LDFLAGS+=("-lm")
    else
        if [ "${CT_CC_GCC_STATIC_LIBSTDCXX}" = "y" ]; then
            # this is from CodeSourcery arm-2010q1-202-arm-none-linux-gnueabi.src.tar.bz2
            # build script
            # INFO: if the host gcc is gcc-4.5 then presumably we could use -static-libstdc++,
            #       see http://gcc.gnu.org/ml/gcc-patches/2009-06/msg01635.html
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++,-Bdynamic")
            host_libstdcxx_flags+=("-lm")
        elif [ "${CT_COMPLIBS_SHARED}" != "y" ]; then
            # When companion libraries are build static (eg !shared),
            # the libstdc++ is not pulled automatically, although it
            # is needed. Shoe-horn it in our LDFLAGS
            # Ditto libm on some Fedora boxen
            final_LDFLAGS+=("-lstdc++")
            final_LDFLAGS+=("-lm")
        fi
    fi

    if [ "${CT_CC_GCC_USE_GMP_MPFR}" = "y" ]; then
        extra_config+=("--with-gmp=${complibs}")
        extra_config+=("--with-mpfr=${complibs}")
    fi
    if [ "${CT_CC_GCC_USE_MPC}" = "y" ]; then
        extra_config+=("--with-mpc=${complibs}")
    fi
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        if [ "${CT_ISL}" = "y" ]; then
            extra_config+=("--with-isl=${complibs}")
        fi
        if [ "${CT_CLOOG}" = "y" ]; then
            extra_config+=("--with-cloog=${complibs}")
        fi
    elif [ "${CT_CC_GCC_HAS_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-isl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--enable-lto")
    elif [ "${CT_CC_GCC_HAS_LTO}" = "y" ]; then
        extra_config+=("--disable-lto")
    fi

    if [ ${#host_libstdcxx_flags[@]} -ne 0 ]; then
        extra_config+=("--with-host-libstdcxx=${host_libstdcxx_flags[*]}")
    fi

    if [ "${CT_THREADS}" = "none" ]; then
        extra_config+=("--disable-threads")
    else
        if [ "${CT_THREADS}" = "win32" ]; then
            extra_config+=("--enable-threads=win32")
            extra_config+=("--disable-win32-registry")
        else
            extra_config+=("--enable-threads=posix")
        fi
    fi

    if [ "${CT_CC_GCC_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
        extra_config+=("--enable-target-optspace")
    fi
    if [ "${CT_CC_GCC_DISABLE_PCH}" = "y" ]; then
        extra_config+=("--disable-libstdcxx-pch")
    fi

    case "${CT_CC_GCC_LDBL_128}" in
        y)  extra_config+=("--with-long-double-128");;
        m)  ;;
        "") extra_config+=("--without-long-double-128");;
    esac

    if [ "${CT_CC_GCC_BUILD_ID}" = "y" ]; then
        extra_config+=( --enable-linker-build-id )
    fi

    case "${CT_CC_GCC_LNK_HASH_STYLE}" in
        "") ;;
        *)  extra_config+=( "--with-linker-hash-style=${CT_CC_GCC_LNK_HASH_STYLE}" );;
    esac

    case "${CT_CC_GCC_DEC_FLOATS}" in
        "") ;;
        *)  extra_config+=( "--enable-decimal-float=${CT_CC_GCC_DEC_FLOATS}" );;
    esac

    if [ "${CT_CC_GCC_ENABLE_PLUGINS}" = "y" ]; then
        extra_config+=( --enable-plugin )
    fi
    if [ "${CT_CC_GCC_GOLD}" = "y" ]; then
        extra_config+=( --enable-gold )
    fi

    case "${CT_ARCH}" in
        mips)
            case "${CT_CC_GCC_mips_llsc}" in
                y)  extra_config+=( --with-llsc );;
                m)  ;;
                *)  extra_config+=( --without-llsc );;
            esac
            case "${CT_CC_GCC_mips_synci}" in
                y)  extra_config+=( --with-synci );;
                m)  ;;
                *)  extra_config+=( --without-synci );;
            esac
            if [ "${CT_CC_GCC_mips_plt}" ]; then
                extra_config+=( --with-mips-plt )
            fi
            ;; # ARCH is mips
    esac

    [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

    if [ "${CT_CC_GCC_SYSTEM_ZLIB}" = "y" ]; then
        extra_config+=("--with-system-zlib")
    fi

    # Some versions of gcc have a defective --enable-multilib.
    # Since that's the default, only pass --disable-multilib.
    if [ "${CT_MULTILIB}" != "y" ]; then
        extra_config+=("--disable-multilib")
    else
        extra_config+=("--enable-multiarch")
        if [ -n "${CT_CC_GCC_MULTILIB_LIST}" ]; then
            extra_config+=("--with-multilib-list=${CT_CC_GCC_MULTILIB_LIST}")
        fi
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # Clang's default bracket-depth is 256, and building GCC
    # requires somewhere between 257 and 512.
    if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
        cflags="$cflags "-fbracket-depth=512
    fi

    CT_DoExecLog CFG                                \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
    CFLAGS="${cflags}"                              \
    CXXFLAGS="${cflags}"                            \
    LDFLAGS="${final_LDFLAGS[*]}"                   \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"         \
    CXXFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"       \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"       \
    "${CT_SRC_DIR}/gcc-${CT_CC_GCC_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${host}                              \
        --target=${CT_TARGET}                       \
        --prefix="${prefix}"                        \
        ${CC_SYSROOT_ARG}                           \
        "${extra_config[@]}"                        \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --enable-long-long                          \
        "${CT_CC_GCC_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${JOBSFLAGS} all-build-libiberty
    fi

    CT_DoLog EXTRA "Building final gcc compiler"
    CT_DoExecLog ALL make ${JOBSFLAGS} all

    # See the note on issues with parallel 'make install' in GCC above.
    CT_DoLog EXTRA "Installing final gcc compiler"
    if [ "${CT_STRIP_TARGET_TOOLCHAIN_EXECUTABLES}" = "y" ]; then
        CT_DoExecLog ALL make install-strip
    else
        CT_DoExecLog ALL make install
    fi

    # Remove the libtool "pseudo-libraries": having them in the installed
    # tree makes the libtoolized utilities that are built next assume
    # that, for example, libsupc++ is an "accessory library", and not include
    # -lsupc++ to the link flags. That breaks ltrace, for example.
    CT_DoLog EXTRA "Housekeeping for final gcc compiler"
    CT_Pushd "${prefix}"
    find . -type f -name "*.la" -exec rm {} \; |CT_DoLog ALL
    CT_Popd

    if [ "${build_manuals}" = "yes" ]; then
        CT_DoLog EXTRA "Building the GCC manuals"
        CT_DoExecLog ALL make pdf html
        CT_DoLog EXTRA "Installing the GCC manuals"
        CT_DoExecLog ALL make install-{pdf,html}-gcc
    fi

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-gcc to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-gcc."* 2>/dev/null || true )"
    [ -z "${file}" ] || ext=".${file##*.}"
    if [ -f "${CT_PREFIX_DIR}/bin/${CT_TARGET}-gcc${ext}" ]; then
        CT_DoExecLog ALL ln -sfv "${CT_TARGET}-gcc${ext}" "${prefix}/bin/${CT_TARGET}-cc${ext}"
    fi

    cc_gcc_multilib_housekeeping cc="${prefix}/bin/${CT_TARGET}-gcc" \
        host="${host}"
}
