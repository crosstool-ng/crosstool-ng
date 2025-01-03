# This file adds the function to build the gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download gcc
do_cc_get() {
    local linaro_version=""
    local linaro_series=""

    CT_Fetch GCC

    # Starting with GCC 4.3, ecj is used for Java, and will only be
    # built if the configure script finds ecj.jar at the top of the
    # GCC source tree, which will not be there unless we get it and
    # put it there ourselves
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y" ]; then
        if ! CT_GetFile package=ecj basename=ecj-latest extensions=.jar dir_name=gcc \
                mirrors="$(CT_Mirrors sourceware java)"; then
            # Should be a package, too - but with Java retirement in GCC,
            # it may not make sense.
            CT_Abort "Failed to download ecj-latest.jar"
        fi
    fi
}

# Extract gcc
do_cc_extract() {
    CT_ExtractPatch GCC

    # Copy ecj-latest.jar to ecj.jar at the top of the GCC source tree
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y" -a ! -f "${CT_SRC_DIR}/gcc/ecj.jar" ]; then
        CT_DoExecLog ALL cp -v "${CT_TARBALLS_DIR}/ecj-latest.jar" "${CT_SRC_DIR}/gcc/ecj.jar"
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
    [ "${CT_CC_LANG_D}" = "y"        ] && lang_list+=",d"
    [ "${CT_CC_LANG_JAVA}" = "y"     ] && lang_list+=",java"
    [ "${CT_CC_LANG_JIT}" = "y"      ] && lang_list+=",jit"
    [ "${CT_CC_LANG_OBJC}" = "y"     ] && lang_list+=",objc"
    [ "${CT_CC_LANG_OBJCXX}" = "y"   ] && lang_list+=",obj-c++"
    [ "${CT_CC_LANG_GOLANG}" = "y"   ] && lang_list+=",go"
    lang_list+="${CT_CC_LANG_OTHERS:+,${CT_CC_LANG_OTHERS}}"

    printf "%s" "${lang_list}"
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

evaluate_multilib_cflags()
{
    local multi_dir multi_os_dir multi_os_dir_gcc multi_root multi_flags multi_index multi_count
    local mdir mdir_os dirtop
    local f

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    mdir="lib/${multi_dir}"
    mdir_os="lib/${multi_os_dir_gcc}"
    CT_SanitizeVarDir mdir mdir_os
    CT_DoLog EXTRA "   '${multi_flags}' --> ${mdir} (gcc)   ${mdir_os} (os)"
    for f in ${multi_flags}; do
        eval ml_`cc_gcc_classify_opt ${f}`=seen
    done
    if [ "${CT_DEMULTILIB}" = "y" -a "${CT_USE_SYSROOT}" = "y" ]; then
        case "${mdir_os}" in
            lib/*)
                ;;
            *)
                dirtop="${mdir_os%%/*}"
                if [ ! -e "${multi_root}/${mdir_os}" ]; then
                    CT_DoExecLog ALL ln -sfv lib "${multi_root}/${mdir_os}"
                fi
                if [ ! -e "${multi_root}/usr/${mdir_os}" ]; then
                    CT_DoExecLog ALL ln -sfv lib "${multi_root}/usr/${mdir_os}"
                fi
                ;;
        esac
    fi
}

#------------------------------------------------------------------------------
# This function lists the multilibs configured in the compiler (even if multilib
# is disabled - so that it lists the default GCC/OS directory, which may differ
# from the default 'lib'). It then performs a few multilib checks/quirks:
#
# 1. On MIPS target, gcc (or rather, ld, which it invokes under the hood) chokes
# if supplied with two -mabi=* options. I.e., 'gcc -mabi=n32' and 'gcc -mabi=32' both
# work, but 'gcc -mabi=32 -mabi=n32' produces an internal error in ld. Thus we do
# not supply target's CFLAGS in multilib builds - and after compiling core gcc,
# attempt to determine which CFLAGS need to be filtered out.
#
# 2. If "demultilibing" is in effect, create top-level directories for any
# multilibs not in lib/ as symlinks to lib.
cc_gcc_multilib_housekeeping() {
    local cc host
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
        cc="${CT_BUILDTOOLS_PREFIX_DIR}/bin/${CT_TARGET}-${CT_CC}"
    fi

    CT_IterateMultilibs evaluate_multilib_cflags evaluate_cflags

    if [ -n "${CT_MULTILIB}" ]; then
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
        CT_EnvModify CT_ALL_TARGET_CFLAGS "${new_cflags} ${CT_TARGET_CFLAGS}"
        CT_EnvModify CT_ARCH_TARGET_CFLAGS_MULTILIB ""

        # Currently, the only LDFLAGS are endianness-related
        CT_DoLog DEBUG "Configured target LDFLAGS: '${CT_ARCH_TARGET_LDFLAGS_MULTILIB}'"
        if [ "${ml_endian}" != "seen" ]; then
            CT_EnvModify CT_ALL_TARGET_LDFLAGS "${CT_ARCH_TARGET_LDFLAGS_MULTILIB} ${CT_TARGET_LDFLAGS}"
            CT_EnvModify CT_ARCH_TARGET_LDFLAGS_MULTILIB ""
        fi
        CT_DoLog DEBUG "Filtered target LDFLAGS: '${CT_ARCH_TARGET_LDFLAGS_MULTILIB}'"
    fi
}

#------------------------------------------------------------------------------
do_cc_core() {
    local -a core_opts

    if [ "${CT_CC_CORE_NEEDED}" != "y" ]; then
        return 0
    fi

    core_opts+=( "mode=static" )
    core_opts+=( "host=${CT_BUILD}" )
    core_opts+=( "complibs=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    core_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    core_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    core_opts+=( "lang_list=c" )
    core_opts+=( "build_step=core" )
    core_opts+=( "mode=static" )
    core_opts+=( "build_libgcc=yes" )

    CT_DoStep INFO "Installing core C gcc compiler"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-cc-gcc-core"

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
#   build_step          : build step 'core', 'gcc_build',
#                         'libstdcxx' or 'gcc_host'                 : string    : (none)
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
    local enable_optspace
    local complibs
    local lang_list
    local cflags cflags_for_build cxxflags_for_build cflags_for_target cxxflags_for_target
    local extra_cxxflags_for_target
    local ldflags
    local build_step
    local log_txt
    local tmp
    local exec_prefix
    local header_dir
    local libstdcxx_name
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a core_LDFLAGS
    local -a core_targets
    local -a core_targets_all
    local -a core_targets_install
    local -a extra_user_config
    local arg
    local file
    local ext

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # This function gets called in case of a bare metal compiler for the final gcc, too.
    case "${build_step}" in
        core)
            CT_DoLog EXTRA "Configuring core C gcc compiler"
            log_txt="gcc"
            extra_config+=( "${CT_CC_CORE_SYSROOT_ARG[@]}" )
            extra_user_config=( "${CT_CC_GCC_CORE_EXTRA_CONFIG_ARRAY[@]}" )
            ;;
        gcc_build|gcc_host)
            CT_DoLog EXTRA "Configuring final gcc compiler"
            extra_config+=( "${CT_CC_SYSROOT_ARG[@]}" )
            extra_config+=( "--with-headers=${CT_PREFIX_DIR}/${CT_TARGET}/include" )
            extra_user_config=( "${CT_CC_GCC_EXTRA_CONFIG_ARRAY[@]}" )
            log_txt="final gcc compiler"
            # to inhibit the libiberty and libgcc tricks later on
            build_libgcc=no
            ;;
        libstdcxx)
            CT_DoLog EXTRA "Configuring libstdc++ for ${libstdcxx_name}"
            if [ -z "${header_dir}" ]; then
                header_dir="${CT_PREFIX_DIR}/${libstdcxx_name}/include"
            fi
            if [ -z "${exec_prefix}" ]; then
                exec_prefix="${CT_PREFIX_DIR}/${libstdcxx_name}"
            fi
            extra_config+=( "${CT_CC_SYSROOT_ARG[@]}" )
            extra_user_config=( "${CT_CC_GCC_EXTRA_CONFIG_ARRAY[@]}" )
            log_txt="libstdc++ ${libstdcxx_name} library"
            # to inhibit the libiberty and libgcc tricks later on
            build_libgcc=no
            ;;
        *)
            CT_Abort "Internal Error: 'build_step' must be one of: 'core', 'gcc_build', 'gcc_host' or 'libstdcxx', not '${build_step:-(empty)}'"
            ;;
    esac

    if [ -z "${exec_prefix}" ]; then
        exec_prefix="${prefix}"
    fi

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

    for tmp in ARCH ABI CPU CPU_32 CPU_64 TUNE FPU FLOAT ENDIAN; do
        eval tmp="\${CT_ARCH_WITH_${tmp}}"
        if [ -n "${tmp}" ]; then
            extra_config+=("${tmp}")
        fi
    done

    [ -n "${CT_PKGVERSION}" ] && extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")

    # Hint GCC we'll use a bit special version of Newlib
    if [ "${CT_LIBC_NEWLIB_NANO_FORMATTED_IO}" = "y" ]; then
        extra_config+=("--enable-newlib-nano-formatted-io")
    fi

    if [ "${CT_CC_LANG_JIT}" = "y" ]; then
        extra_config+=("--enable-host-shared")
    fi

    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config+=("--enable-__cxa_atexit")
    else
        extra_config+=("--disable-__cxa_atexit")
    fi

    case "${CT_CC_GCC_TM_CLONE_REGISTRY}" in
        y) extra_config+=("--enable-tm-clone-registry");;
        m) ;;
        "") extra_config+=("--disable-tm-clone-registry");;
    esac

    if [ -n "${CT_CC_GCC_ENABLE_CXX_FLAGS}" \
            -a "${mode}" = "baremetal" ]; then
        extra_config+=("--enable-cxx-flags=${CT_CC_GCC_ENABLE_CXX_FLAGS}")
    fi

    extra_config+=(--disable-libgomp)
    extra_config+=(--disable-libmudflap)
    extra_config+=(--disable-libmpx)

    case "${CT_CC_GCC_LIBSSP}" in
        y)  extra_config+=(--enable-libssp);;
        m)  ;;
        "") extra_config+=(--disable-libssp);;
    esac
    if [ "${CT_CC_GCC_LIBQUADMATH}" = "y" ]; then
        extra_config+=(--enable-libquadmath)
        extra_config+=(--enable-libquadmath-support)
    else
        extra_config+=(--disable-libquadmath)
        extra_config+=(--disable-libquadmath-support)
    fi

    case "${CT_CC_GCC_LIBSTDCXX_VERBOSE}" in
        y)  extra_config+=("--enable-libstdcxx-verbose");;
        m)  ;;
        "") extra_config+=("--disable-libstdcxx-verbose");;
    esac

    if [ "${build_libstdcxx}" = "yes" ]; then
        if [ "${CT_CC_GCC_LIBSTDCXX}" = "n" ]; then
            build_libstdcxx="no"
        elif [ "${CT_CC_GCC_LIBSTDCXX}" = "y" ]; then
            extra_config+=("--enable-libstdcxx")
        fi

        if [ "${CT_LIBC_AVR_LIBC}" = "y" ]; then
            extra_config+=("--enable-cstdio=stdio_pure")
        fi

        if [ "${CT_CC_GCC_LIBSTDCXX_HOSTED_DISABLE}" = "y" ]; then
            extra_config+=("--disable-libstdcxx-hosted")
        fi
    fi

    if [ "${build_libstdcxx}" = "no" ]; then
        extra_config+=(--disable-libstdcxx)
    fi

    if [ "${CT_LIBC_PICOLIBC}" = "y" ]; then
        extra_config+=("--with-default-libc=picolibc")
        extra_config+=("--enable-stdio=pure")
        if [ "${CT_PICOLIBC_older_than_1_8}" = "y" ]; then
            extra_config+=("--disable-wchar_t")
        fi
    fi

    core_LDFLAGS+=("${ldflags}")

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_gcc_backend, below.
    if [ "${build_staticlinked}" = "yes" ]; then
        core_LDFLAGS+=("-static")
        if [ "${CT_GCC_older_than_6}" = "y" ]; then
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++")
            host_libstdcxx_flags+=("-lm")
        fi
    else
        if [ "${CT_CC_GCC_STATIC_LIBSTDCXX}" = "y" -a "${CT_GCC_older_than_6}" = "y" ]; then
            # this is from CodeSourcery arm-2010q1-202-arm-none-linux-gnueabi.src.tar.bz2
            # build script
            # INFO: if the host gcc is gcc-4.5 then presumably we could use -static-libstdc++,
            #       see http://gcc.gnu.org/ml/gcc-patches/2009-06/msg01635.html
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++,-Bdynamic")
            host_libstdcxx_flags+=("-lm")
        fi
    fi

    extra_config+=("--with-gmp=${complibs}")
    extra_config+=("--with-mpfr=${complibs}")
    extra_config+=("--with-mpc=${complibs}")
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        if [ "${CT_ISL}" = "y" ]; then
            extra_config+=("--with-isl=${complibs}")
        fi
        if [ "${CT_CLOOG}" = "y" ]; then
            extra_config+=("--with-cloog=${complibs}")
        fi
    else
        extra_config+=("--with-isl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--enable-lto")
    else
        extra_config+=("--disable-lto")
    fi

    if [ ${#host_libstdcxx_flags[@]} -ne 0 ]; then
        extra_config+=("--with-host-libstdcxx=${host_libstdcxx_flags[*]}")
    fi

    if [ "${CT_CC_GCC_ENABLE_DEFAULT_PIE}" = "y" ]; then
        extra_config+=("--enable-default-pie")
    fi

    if [ "${CT_CC_GCC_ENABLE_TARGET_OPTSPACE}" = "y" ] || \
       [ "${enable_optspace}" = "yes" ]; then
        extra_config+=("--enable-target-optspace")
    fi
    if [ "${CT_CC_GCC_DISABLE_PCH}" = "y" ]; then
        extra_config+=("--disable-libstdcxx-pch")
    fi

    if [ "${CT_LIBC_GLIBC}" = "y" ]; then
        # Report GLIBC's version to GCC, it affects the defaults on other options.
        # GCC expects just two numbers separated by a dot.
        local glibc_version

        CT_GetPkgVersion GLIBC glibc_version
        case "${glibc_version}" in
        new) glibc_version=99.99;;
        old) glibc_version=1.0;;
        *) glibc_version=`echo "${glibc_version}" | sed 's/\([1-9][0-9]*\.[1-9][0-9]*\).*/\1/'`;;
        esac
        extra_config+=("--with-glibc-version=${glibc_version}")
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
    else
        extra_config+=( --disable-plugin )
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

    if [ "${CT_TOOLCHAIN_ENABLE_NLS}" = "y" ]; then
        extra_config+=("--with-libintl-prefix=${complibs}")
    else
        extra_config+=("--disable-nls")
    fi

    if [ "${CT_CC_GCC_SYSTEM_ZLIB}" = "y" ]; then
        extra_config+=("--with-system-zlib")
    fi

    case "${CT_CC_GCC_CONFIG_TLS}" in
        y)  extra_config+=("--enable-tls");;
        m)  ;;
        "") extra_config+=("--disable-tls");;
    esac

    # In baremetal, we only build the Ada compiler without its runtime.
    # The runtime will need to be provided externaly by the user.
    if [    "${mode}" = "baremetal"    \
         -a "${CT_CC_LANG_ADA}"  = "y"    \
       ]; then
        extra_config+=("--disable-libada" )
    fi

    # In baremetal, we only build the D compiler without its runtime.
    # The runtime will need to be provided externaly by the user.
    if [    "${mode}" = "baremetal"    \
         -a "${CT_CC_LANG_D}"  = "y"    \
       ]; then
        extra_config+=("--disable-libphobos" )
    fi

    # Some versions of gcc have a defective --enable-multilib.
    # Since that's the default, only pass --disable-multilib. For multilib,
    # also enable multiarch. Without explicit --enable-multiarch, core
    # compiler is configured as multilib/no-multiarch (because gcc autodetects
    # multiarch based on multiple instances of crt*.o in the install directory
    # which do not exist in the core pass).
    if [ "${CT_MULTILIB}" != "y" ]; then
        extra_config+=("--disable-multilib")
    else
        extra_config+=("--enable-multiarch")
        if [ -n "${CT_CC_GCC_MULTILIB_LIST}" ]; then
            extra_config+=("--with-multilib-list=${CT_CC_GCC_MULTILIB_LIST}")
        fi
        if [ -n "${CT_CC_GCC_MULTILIB_GENERATOR}" ]; then
            extra_config+=("--with-multilib-generator=${CT_CC_GCC_MULTILIB_GENERATOR}")
        fi
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # We may need to modify host/build/target CFLAGS separately below. Note
    # that ${cflags} may refer either to build or host CFLAGS; they are provided
    # by the caller.
    cflags_for_build="${CT_CFLAGS_FOR_BUILD}"
    cxxflags_for_build="${CT_CXXFLAGS_FOR_BUILD}"
    cflags_for_target="${CT_TARGET_CFLAGS}"

    # Clang's default bracket-depth is 256, and building GCC
    # requires somewhere between 257 and 512.
    if [ "${host}" = "${CT_BUILD}" ]; then
        if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
            cflags="$cflags -fbracket-depth=512"
            cflags_for_build="$cflags_for_build -fbracket-depth=512"
        fi
    else
        # FIXME we currently don't support clang as host compiler, only as build
        if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
            cflags_for_build="$cflags_for_build -fbracket-depth=512"
        fi
    fi

    # Add an extra system include dir if we have one. This is especially useful
    # when building libstdc++ with a libc other than the system libc (e.g.
    # picolibc)
    if [ -n "${header_dir}" ]; then
        cflags_for_target="${cflags_for_target} -idirafter ${header_dir}"
    fi

    # For non-sysrooted toolchain, GCC doesn't search except at the installation
    # prefix; in core stage we use a temporary installation prefix - but
    # we may have installed something into the final prefix. This is less than ideal:
    # in the installation prefix GCC also handles subdirectories for multilibs
    # (e.g. first trying ${prefix}/include/${arch-triplet}) but
    # we can only pass the top level directory, so non-sysrooted build with libc
    # selection that doesn't merge the headers (i.e. musl, uClibc-ng) may not
    # work. Better suggestions welcome.
    if [ "${CT_USE_SYSROOT}" != "y" ]; then
        cflags_for_target="${cflags_for_target} -idirafter ${CT_HEADERS_DIR}"
    fi

    # Assume '-O2' by default for building target libraries.
    cflags_for_target="-g -O2 ${cflags_for_target}"

    # Set target CXXFLAGS to CFLAGS if none is provided.
    if [ -z "${cxxflags_for_target}" ]; then
        cxxflags_for_target="${cflags_for_target}"
    fi

    # Append extra CXXFLAGS if provided.
    if [ -n "${extra_cxxflags_for_target}" ]; then
        cxxflags_for_target="${cxxflags_for_target} ${extra_cxxflags_for_target}"
    fi

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532).
    # Pass only user-specified CFLAGS/LDFLAGS in CFLAGS_FOR_TARGET/LDFLAGS_FOR_TARGET: during
    # the build of, for example, libatomic, GCC tried to compile multiple variants for runtime
    # selection and passing architecture/CPU selectors, as detemined by crosstool-NG, may
    # miscompile or outright fail.
    CT_DoExecLog CFG                                   \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                     \
    CFLAGS="${cflags}"                                 \
    CFLAGS_FOR_BUILD="${cflags_for_build}"             \
    CXXFLAGS="${cflags} ${cxxflags_for_build}"         \
    CXXFLAGS_FOR_BUILD="${cflags_for_build} ${cxxflags_for_build}" \
    LDFLAGS="${core_LDFLAGS[*]}"                       \
    CFLAGS_FOR_TARGET="${cflags_for_target}"           \
    CXXFLAGS_FOR_TARGET="${cxxflags_for_target}"       \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"          \
    ${CONFIG_SHELL}                                    \
    "${CT_SRC_DIR}/gcc/configure"                      \
        --build=${CT_BUILD}                            \
        --host=${host}                                 \
        --target=${CT_TARGET}                          \
        --prefix="${prefix}"                           \
        --exec_prefix="${exec_prefix}"                 \
        --with-local-prefix="${CT_SYSROOT_DIR}"        \
        "${extra_config[@]}"                           \
        --enable-languages="${lang_list}"              \
        "${extra_user_config[@]}"

    gcc_core_build_libcpp=all-build-libcpp
    # disable target all-build-libcpp in gcc older verions
    if [ "${CT_GCC_older_than_5}" = "y" ]; then
        gcc_core_build_libcpp=""
    fi

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
        if [ ! -f "${CT_SRC_DIR}/gcc/gcc/BASE-VER" ]; then
            CT_DoExecLog CFG make ${CT_JOBSFLAGS} configure-libiberty
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -C libiberty libiberty.a
            CT_DoExecLog CFG make ${CT_JOBSFLAGS} configure-gcc configure-libcpp
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} all-libcpp ${gcc_core_build_libcpp}
        else
            CT_DoExecLog CFG make ${CT_JOBSFLAGS} configure-gcc configure-libcpp configure-build-libiberty
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} all-libcpp ${gcc_core_build_libcpp} all-build-libiberty
        fi
        # HACK: gcc-4.2 uses libdecnumber to build libgcc.mk, so build it here.
        if [ -d "${CT_SRC_DIR}/gcc/libdecnumber" ]; then
            CT_DoExecLog CFG make ${CT_JOBSFLAGS} configure-libdecnumber
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -C libdecnumber libdecnumber.a
        fi
        # HACK: gcc-4.8 uses libbacktrace to make libgcc.mvars, so make it here.
        if [ -d "${CT_SRC_DIR}/gcc/libbacktrace" ]; then
            CT_DoExecLog CFG make ${CT_JOBSFLAGS} configure-libbacktrace
            CT_DoExecLog ALL make ${CT_JOBSFLAGS} -C libbacktrace
        fi

        libgcc_rule="libgcc.mvars"
        core_targets=( gcc target-libgcc )

        CT_DoExecLog ALL make ${CT_JOBSFLAGS} -C gcc ${libgcc_rule}

        sed -r -i -e 's@-lc@@g' gcc/${libgcc_rule}
    else # build_libgcc
        core_targets=( gcc )
    fi   # ! build libgcc
    if [ "${build_libstdcxx}" = "yes" ]; then
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
            core_targets_all=all
            core_targets_install=install
            ;;
        libstdcxx)
            core_targets=( target-libstdc++-v3 )
            core_targets_all="${core_targets[@]/#/all-}"
            core_targets_install="${core_targets[@]/#/install-}"
            ;;
    esac

    CT_DoLog EXTRA "Building ${log_txt}"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS} ${core_targets_all}

    # In case of baremetal, the gnat* tools are not built automatically.
    if [    "${mode}" = "baremetal"    \
         -a "${CT_CC_LANG_ADA}"  = "y"    \
       ]; then
        CT_DoLog EXTRA "Building gnattools for baremetal"
        CT_DoExecLog ALL make -C gcc ${CT_JOBSFLAGS} cross-gnattools
    fi

    # Do not pass ${CT_JOBSFLAGS} here: recent GCC builds have been failing
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

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-${CT_CC} to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${prefix}/bin/${CT_TARGET}-${CT_CC}."* 2>/dev/null || true )"
    [ -z "${file}" ] && ext="" || ext=".${file##*.}"
    if [ -f "${prefix}/bin/${CT_TARGET}-${CT_CC}${ext}" ]; then
        CT_DoExecLog ALL ln -sfv "${CT_TARGET}-${CT_CC}${ext}" "${prefix}/bin/${CT_TARGET}-cc${ext}"
    fi

    cc_gcc_multilib_housekeeping cc="${prefix}/bin/${CT_TARGET}-${CT_CC}" \
        host="${host}"

    # If binutils want the LTO plugin, point them to it
    if [ -d "${CT_PREFIX_DIR}/lib/bfd-plugins" -a "${build_step}" = "gcc_host" ]; then
        local gcc_version=$(cat "${CT_SRC_DIR}/gcc/gcc/BASE-VER" )
        local plugins_dir="libexec/gcc/${CT_TARGET}/${gcc_version}"
        file="$( ls -1 "${CT_PREFIX_DIR}/${plugins_dir}/liblto_plugin."* 2>/dev/null | \
            sort | head -n1 || true )"
        [ -z "${file}" ] && ext="" || ext=".${file##*.}"
        CT_DoExecLog ALL ln -sfv "../../${plugins_dir}/liblto_plugin${ext}" \
                "${CT_PREFIX_DIR}/lib/bfd-plugins/liblto_plugin${ext}"
    fi
}

#------------------------------------------------------------------------------
# Build complete gcc to run on build
do_cc_for_build() {
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

gcc_movelibs()
{
    local multi_flags multi_dir multi_os_dir multi_os_dir_gcc multi_root multi_index multi_count
    local gcc_dir dst_dir canon_root canon_prefix
    local rel

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # GCC prints the sysroot in canonicalized form, which may be different if there
    # is a symlink in the path. Since we need textual match to obtain a relative
    # subdirectory path, canonicalize the prefix directory. Since GCC's behavior
    # is not documented and hence may change at any time, canonicalize it too just
    # for the good measure.
    canon_root=$( cd "${multi_root}" && pwd -P )
    canon_prefix=$( cd "${CT_PREFIX_DIR}" && pwd -P )

    # Move only files, directories are for other multilibs. We're looking inside
    # GCC's directory structure, thus use unmangled multi_os_dir that GCC reports.
    gcc_dir="${canon_prefix}/${CT_TARGET}/lib/${multi_os_dir_gcc}"
    if [ ! -d "${gcc_dir}" ]; then
        # GCC didn't install anything outside of sysroot
        return
    fi
    # Depending on the selected libc, we may or may not have the ${multi_os_dir_gcc}
    # created by libc installation. If we do, use it. If we don't, use ${multi_os_dir}
    # to avoid creating an otherwise empty directory.
    dst_dir="${canon_root}/lib/${multi_os_dir_gcc}"
    if [ ! -d "${dst_dir}" ]; then
        dst_dir="${canon_root}/lib/${multi_os_dir}"
    fi
    CT_SanitizeVarDir dst_dir gcc_dir
    rel=$( echo "${gcc_dir#${canon_prefix}/}" | sed 's#[^/]\{1,\}#..#g' )

    ls "${gcc_dir}" | while read f; do
        case "${f}" in
            *.ld)
                # Linker scripts remain in GCC's directory; elf2flt insists on
                # finding them there.
                continue
                ;;
        esac
        if [ -f "${gcc_dir}/${f}" ]; then
            CT_DoExecLog ALL mkdir -p "${dst_dir}"
            CT_DoExecLog ALL mv "${gcc_dir}/${f}" "${dst_dir}/${f}"
            CT_DoExecLog ALL ln -sf "${rel}/${dst_dir#${canon_prefix}/}/${f}" "${gcc_dir}/${f}"
        fi
    done
}

#------------------------------------------------------------------------------
# Build final gcc to run on host
do_cc_for_host() {
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
#   exec_prefix   : prefix for executables              : dir       : (none)
#   complibs      : the companion libraries prefix      : dir       : (none)
#   cflags        : cflags to use                       : string    : (empty)
#   ldflags       : ldflags to use                      : string    : (empty)
#   lang_list     : the list of languages to build      : string    : (empty)
#   build_manuals : whether to build manuals or not     : bool      : no
#   build_step    : build step 'gcc_build', 'gcc_host'
#                   or 'libstdcxx'                      : string    : (none)
do_gcc_backend() {
    local host
    local prefix
    local exec_prefix
    local complibs
    local lang_list
    local cflags
    local cflags_for_build
    local cxxflags_for_build
    local cflags_for_target
    local cxxflags_for_target
    local extra_cxxflags_for_target
    local ldflags
    local build_manuals
    local header_dir
    local libstdcxx_name
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a final_LDFLAGS
    local tmp
    local arg
    local file
    local ext

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    if [ -z "${exec_prefix}" ]; then
        exec_prefix="${prefix}"
    fi

    # This function gets called for final gcc and libstdcxx.
    case "${build_step}" in
        gcc_build|gcc_host)
            log_txt="final gcc compiler"
            ;;
        libstdcxx)
            log_txt="libstdc++ library for ${libstdcxx_name}"
            ;;
        *)
            CT_Abort "Internal Error: 'build_step' must be one of: 'gcc_build', 'gcc_host' or 'libstdcxx', not '${build_step:-(empty)}'"
            ;;
    esac

    CT_DoLog EXTRA "Configuring ${log_txt}"

    # Enable selected languages
    extra_config+=("--enable-languages=${lang_list}")

    for tmp in ARCH ARCH_32 ARCH_64 ABI CPU CPU_32 CPU_64 TUNE TUNE_32 TUNE_64 FPU FLOAT; do
        eval tmp="\${CT_ARCH_WITH_${tmp}}"
        if [ -n "${tmp}" ]; then
            extra_config+=("${tmp}")
        fi
    done

    [ -n "${CT_PKGVERSION}" ] && extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
    [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")

    if [ "${CT_SHARED_LIBS}" != "y" ]; then
        extra_config+=("--disable-shared")
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

    case "${CT_CC_GCC_TM_CLONE_REGISTRY}" in
        y) extra_config+=("--enable-tm-clone-registry");;
        m) ;;
        "") extra_config+=("--disable-tm-clone-registry");;
    esac

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
    case "${CT_CC_GCC_LIBSSP}" in
        y)  extra_config+=(--enable-libssp);;
        m)  ;;
        "") extra_config+=(--disable-libssp);;
    esac
    if [ "${CT_CC_GCC_LIBQUADMATH}" = "y" ]; then
        extra_config+=(--enable-libquadmath)
        extra_config+=(--enable-libquadmath-support)
    else
        extra_config+=(--disable-libquadmath)
        extra_config+=(--disable-libquadmath-support)
    fi

    case "${CT_CC_GCC_LIBSANITIZER}" in
        y) extra_config+=(--enable-libsanitizer);;
        m) ;;
        "") extra_config+=(--disable-libsanitizer);;
    esac

    if [ "${CT_CC_GCC_HAS_LIBMPX}" = "y" ]; then
        if [ "${CT_CC_GCC_LIBMPX}" = "y" ]; then
            extra_config+=(--enable-libmpx)
        else
            extra_config+=(--disable-libmpx)
        fi
    fi

    case "${CT_CC_GCC_LIBSTDCXX_VERBOSE}" in
        y)  extra_config+=("--enable-libstdcxx-verbose");;
        m)  ;;
        "") extra_config+=("--disable-libstdcxx-verbose");;
    esac
    
    if [ "${CT_CC_GCC_LIBSTDCXX}" = "n" ]; then
        extra_config+=(--disable-libstdcxx)
    elif [ "${CT_CC_GCC_LIBSTDCXX}" = "y" ]; then
        extra_config+=(--enable-libstdcxx)
    fi

    if [ "${CT_CC_GCC_LIBSTDCXX_HOSTED_DISABLE}" = "y" ]; then
        extra_config+=("--disable-libstdcxx-hosted")
    fi

    if [ "${CT_LIBC_AVR_LIBC}" = "y" ]; then
        extra_config+=("--enable-cstdio=stdio_pure")
    fi

    if [ "${CT_LIBC_PICOLIBC}" = "y" ]; then
        extra_config+=("--with-default-libc=picolibc")
        extra_config+=("--enable-stdio=pure")
        extra_config+=("--disable-wchar_t")
    fi

    final_LDFLAGS+=("${ldflags}")

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_gcc_core_backend, above.
    if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
        final_LDFLAGS+=("-static")
        if [ "${CT_GCC_older_than_6}" = "y" ]; then
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++")
            host_libstdcxx_flags+=("-lm")
        fi
    else
        if [ "${CT_CC_GCC_STATIC_LIBSTDCXX}" = "y" -a "${CT_GCC_older_than_6}" = "y" ]; then
            # this is from CodeSourcery arm-2010q1-202-arm-none-linux-gnueabi.src.tar.bz2
            # build script
            # INFO: if the host gcc is gcc-4.5 then presumably we could use -static-libstdc++,
            #       see http://gcc.gnu.org/ml/gcc-patches/2009-06/msg01635.html
            host_libstdcxx_flags+=("-static-libgcc")
            host_libstdcxx_flags+=("-Wl,-Bstatic,-lstdc++,-Bdynamic")
            host_libstdcxx_flags+=("-lm")
        fi
    fi

    extra_config+=("--with-gmp=${complibs}")
    extra_config+=("--with-mpfr=${complibs}")
    extra_config+=("--with-mpc=${complibs}")
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        if [ "${CT_ISL}" = "y" ]; then
            extra_config+=("--with-isl=${complibs}")
        fi
        if [ "${CT_CLOOG}" = "y" ]; then
            extra_config+=("--with-cloog=${complibs}")
        fi
    else
        extra_config+=("--with-isl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--enable-lto")
    else
        extra_config+=("--disable-lto")
    fi
    case "${CT_CC_GCC_LTO_ZSTD}" in
        y) extra_config+=("--with-zstd=${complibs}");;
        m) ;;
        *) extra_config+=("--without-zstd");;
    esac

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

    if [ "${CT_CC_GCC_ENABLE_TARGET_OPTSPACE}" = "y" ] || \
       [ "${enable_optspace}" = "yes" ]; then
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
    else
        extra_config+=( --disable-plugin )
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

    if [ "${CT_TOOLCHAIN_ENABLE_NLS}" = "y" ]; then
        extra_config+=("--with-libintl-prefix=${complibs}")
    else
        extra_config+=("--disable-nls")
    fi

    if [ "${CT_CC_GCC_SYSTEM_ZLIB}" = "y" ]; then
        extra_config+=("--with-system-zlib")
    fi

    case "${CT_CC_GCC_CONFIG_TLS}" in
        y)  extra_config+=("--enable-tls");;
        m)  ;;
        "") extra_config+=("--disable-tls");;
    esac

    # Some versions of gcc have a defective --enable-multilib.
    # Since that's the default, only pass --disable-multilib.
    if [ "${CT_MULTILIB}" != "y" ]; then
        extra_config+=("--disable-multilib")
    else
        extra_config+=("--enable-multiarch")
        if [ -n "${CT_CC_GCC_MULTILIB_LIST}" ]; then
            extra_config+=("--with-multilib-list=${CT_CC_GCC_MULTILIB_LIST}")
        fi
        if [ -n "${CT_CC_GCC_MULTILIB_GENERATOR}" ]; then
            extra_config+=("--with-multilib-generator=${CT_CC_GCC_MULTILIB_GENERATOR}")
        fi
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # We may need to modify host/build/target CFLAGS separately below
    cflags_for_build="${cflags}"
    cxxflags_for_build="${CT_CXXFLAGS_FOR_BUILD}"
    cflags_for_target="${CT_TARGET_CFLAGS}"

    # Clang's default bracket-depth is 256, and building GCC
    # requires somewhere between 257 and 512.
    if [ "${host}" = "${CT_BUILD}" ]; then
        if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
            cflags="$cflags "-fbracket-depth=512
            cflags_for_build="$cflags_for_build "-fbracket-depth=512
        fi
    else
        # FIXME we currently don't support clang as host compiler, only as build
        if ${CT_BUILD}-gcc --version 2>&1 | grep clang; then
            cflags_for_build="$cflags_for_build "-fbracket-depth=512
        fi
    fi

    # Add an extra system include dir if we have one. This is especially useful
    # when building libstdc++ with a libc other than the system libc (e.g.
    # picolibc)
    if [ -n "${header_dir}" ]; then
        cflags_for_target="${cflags_for_target} -idirafter ${header_dir}"
    fi

    # Assume '-O2' by default for building target libraries.
    cflags_for_target="-g -O2 ${cflags_for_target}"

    # Set target CXXFLAGS to CFLAGS if none is provided.
    if [ -z "${cxxflags_for_target}" ]; then
        cxxflags_for_target="${cflags_for_target}"
    fi

    # Append extra CXXFLAGS if provided.
    if [ -n "${extra_cxxflags_for_target}" ]; then
        cxxflags_for_target="${cxxflags_for_target} ${extra_cxxflags_for_target}"
    fi

    # NB: not using CT_ALL_TARGET_CFLAGS/CT_ALL_TARGET_LDFLAGS here!
    # See do_gcc_core_backend for explanation.
    CT_DoExecLog CFG                                   \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                     \
    CFLAGS="${cflags}"                                 \
    CFLAGS_FOR_BUILD="${cflags_for_build}"             \
    CXXFLAGS="${cflags} ${cxxflags_for_build}"         \
    CXXFLAGS_FOR_BUILD="${cflags_for_build} ${cxxflags_for_build}" \
    LDFLAGS="${final_LDFLAGS[*]}"                      \
    CFLAGS_FOR_TARGET="${cflags_for_target}"           \
    CXXFLAGS_FOR_TARGET="${cxxflags_for_target}"       \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"          \
    ${CONFIG_SHELL}                                    \
    "${CT_SRC_DIR}/gcc/configure"                      \
        --build=${CT_BUILD}                            \
        --host=${host}                                 \
        --target=${CT_TARGET}                          \
        --prefix="${prefix}"                           \
        --exec_prefix="${exec_prefix}"                 \
        "${CT_CC_SYSROOT_ARG[@]}"                      \
        "${extra_config[@]}"                           \
        --with-local-prefix="${CT_SYSROOT_DIR}"        \
        --enable-long-long                             \
        "${CT_CC_GCC_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${CT_JOBSFLAGS} all-build-libiberty
    fi

    CT_DoLog EXTRA "Building final gcc compiler"
    CT_DoExecLog ALL make ${CT_JOBSFLAGS} all

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

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-${CT_CC} to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${CT_CC}."* 2>/dev/null || true )"
    [ -z "${file}" ] && ext="" || ext=".${file##*.}"
    if [ -f "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${CT_CC}${ext}" ]; then
        CT_DoExecLog ALL ln -sfv "${CT_TARGET}-${CT_CC}${ext}" "${prefix}/bin/${CT_TARGET}-cc${ext}"
    fi

    cc_gcc_multilib_housekeeping cc="${prefix}/bin/${CT_TARGET}-${CT_CC}" \
        host="${host}"

    # If binutils want the LTO plugin, point them to it
    if [ -d "${CT_PREFIX_DIR}/lib/bfd-plugins" -a "${build_step}" = "gcc_host" ]; then
        local gcc_version=$(cat "${CT_SRC_DIR}/gcc/gcc/BASE-VER" )
        local plugins_dir="libexec/gcc/${CT_TARGET}/${gcc_version}"
        file="$( ls -1 "${CT_PREFIX_DIR}/${plugins_dir}/liblto_plugin."* 2>/dev/null | \
            sort | head -n1 || true )"
        [ -z "${file}" ] && ext="" || ext=".${file##*.}"
        CT_DoExecLog ALL ln -sfv "../../${plugins_dir}/liblto_plugin${ext}" \
                "${CT_PREFIX_DIR}/lib/bfd-plugins/liblto_plugin${ext}"
    fi
}
