# This file adds the function to build the gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download gcc
do_cc_get() {
    local linaro_version
    local linaro_series
    local linaro_base_url="http://launchpad.net/gcc-linaro"


    # Account for the Linaro versioning
    linaro_version="$( echo "${CT_CC_VERSION}"      \
                       |sed -r -e 's/^linaro-//;'   \
                     )"
    linaro_series="$( echo "${linaro_version}"      \
                      |sed -r -e 's/-.*//;'         \
                    )"

    # Ah! gcc folks are kind of 'different': they store the tarballs in
    # subdirectories of the same name! That's because gcc is such /crap/ that
    # it is such /big/ that it needs being splitted for distribution! Sad. :-(
    # Arrgghh! Some of those versions does not follow this convention:
    # gcc-3.3.3 lives in releases/gcc-3.3.3, while gcc-2.95.* isn't in a
    # subdirectory! You bastard!
    CT_GetFile "gcc-${CT_CC_VERSION}"                                                       \
               {ftp,http}://ftp.gnu.org/gnu/gcc{,{,/releases}/gcc-${CT_CC_VERSION}}         \
               ftp://ftp.irisa.fr/pub/mirrors/gcc.gnu.org/gcc/releases/gcc-${CT_CC_VERSION} \
               ftp://ftp.uvsq.fr/pub/gcc/snapshots/${CT_CC_VERSION}                         \
               "${linaro_base_url}/${linaro_series}/${linaro_version}/+download"

    # Starting with GCC 4.3, ecj is used for Java, and will only be
    # built if the configure script finds ecj.jar at the top of the
    # GCC source tree, which will not be there unless we get it and
    # put it there ourselves
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y" ]; then
        CT_GetFile ecj-latest .jar ftp://gcc.gnu.org/pub/java   \
                                   ftp://sourceware.org/pub/java
    fi
}

# Extract gcc
do_cc_extract() {
    CT_Extract "gcc-${CT_CC_VERSION}"
    CT_Patch "gcc" "${CT_CC_VERSION}"

    # Copy ecj-latest.jar to ecj.jar at the top of the GCC source tree
    if [ "${CT_CC_LANG_JAVA_USE_ECJ}" = "y"                     \
         -a ! -f "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/ecj.jar"   \
       ]; then
        CT_DoExecLog ALL cp -v "${CT_TARBALLS_DIR}/ecj-latest.jar" "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/ecj.jar"
    fi
}

#------------------------------------------------------------------------------
# Core gcc pass 1
do_cc_core_pass_1() {
    # If we're building for bare metal, build the static core gcc,
    # with libgcc.
    # In case we're not bare metal and building a canadian compiler, do nothing
    # In case we're not bare metal, and we're NPTL, build the static core gcc.
    # In any other case, do nothing.
    case "${CT_BARE_METAL},${CT_CANADIAN},${CT_THREADS}" in
        y,*,*)  do_cc_core mode=static;;
        ,y,*)   ;;
        ,,nptl) do_cc_core mode=static;;
        *)      ;;
    esac
}

# Core gcc pass 2
do_cc_core_pass_2() {
    # In case we're building for bare metal, do nothing, we already have
    # our compiler.
    # In case we're not bare metal and building a canadian compiler, do nothing
    # In case we're NPTL, build the shared core gcc and the target libgcc.
    # In any other case, build the static core gcc and, if using gcc-4.3+,
    # also build the target libgcc.
    case "${CT_BARE_METAL},${CT_CANADIAN},${CT_THREADS}" in
        y,*,*)
            if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
                do_cc_core mode=baremetal build_libgcc=yes build_libstdcxx=yes build_staticlinked=yes
            else
                do_cc_core mode=baremetal build_libgcc=yes build_libstdcxx=yes
            fi
            ;;
        ,y,*)   ;;
        ,,nptl)
            do_cc_core mode=shared build_libgcc=yes
            ;;
        ,,win32)
            do_cc_core mode=static build_libgcc=yes
            ;;
        *)  if [ "${CT_CC_GCC_4_3_or_later}" = "y" ]; then
                do_cc_core mode=static build_libgcc=yes
            else
                do_cc_core mode=static
            fi
            ;;
    esac
}

#------------------------------------------------------------------------------
# Build core gcc
# This function is used to build both the static and the shared core C conpiler,
# with or without the target libgcc. We need to know wether:
#  - we're building static, shared or bare metal: mode=[static|shared|baremetal]
#  - we need to build libgcc or not             : build_libgcc=[yes|no]       (default: no)
#  - we need to build libstdc++ or not          : build_libstdcxx=[yes|no]    (default: no)
#  - we need to build statically linked or not  : build_staticlinked=[yes|no] (default: no)
# Usage: do_cc_core mode=[static|shared|baremetal] build_libgcc=[yes|no] build_staticlinked=[yes|no]
do_cc_core() {
    local mode
    local build_libgcc=no
    local build_libstdcxx=no
    local build_staticlinked=no
    local core_prefix_dir
    local lang_opt
    local tmp
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a core_LDFLAGS
    local -a core_targets

    while [ $# -ne 0 ]; do
        eval "${1}"
        shift
    done

    lang_opt=c
    case "${mode}" in
        static)
            core_prefix_dir="${CT_CC_CORE_STATIC_PREFIX_DIR}"
            extra_config+=("--with-newlib")
            extra_config+=("--enable-threads=no")
            extra_config+=("--disable-shared")
            copy_headers=y  # For baremetal, as there's no headers to copy,
                            # we copy an empty directory. So, who cares?
            ;;
        shared)
            core_prefix_dir="${CT_CC_CORE_SHARED_PREFIX_DIR}"
            extra_config+=("--enable-shared")
            copy_headers=y
            ;;
        baremetal)
            core_prefix_dir="${CT_PREFIX_DIR}"
            extra_config+=("--with-newlib")
            extra_config+=("--enable-threads=no")
            extra_config+=("--disable-shared")
            [ "${CT_CC_LANG_CXX}" = "y" ] && lang_opt="${lang_opt},c++"
            copy_headers=n
            ;;
        *)
            CT_Abort "Internal Error: 'mode' must be one of: 'static', 'shared' or 'baremetal', not '${mode:-(empty)}'"
            ;;
    esac

    CT_DoStep INFO "Installing ${mode} core C compiler"
    mkdir -p "${CT_BUILD_DIR}/build-cc-core-${mode}"
    cd "${CT_BUILD_DIR}/build-cc-core-${mode}"

    if [ "${CT_CC_GCC_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        # Bare metal delivers the core compiler as final compiler, so add version info and bugurl
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    if [ "${copy_headers}" = "y" ]; then
        CT_DoLog DEBUG "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
        CT_DoExecLog ALL cp -a "${CT_HEADERS_DIR}" "${core_prefix_dir}/${CT_TARGET}/include"
    fi

    CT_DoLog EXTRA "Configuring ${mode} core C compiler"

    for tmp in ARCH ABI CPU TUNE FPU FLOAT; do
        eval tmp="\${CT_ARCH_WITH_${tmp}}"
        if [ -n "${tmp}" ]; then
            extra_config+=("${tmp}")
        fi
    done
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config+=("--enable-__cxa_atexit")
    else
        extra_config+=("--disable-__cxa_atexit")
    fi

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_cc, below.
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
        if [ "${CT_CC_STATIC_LIBSTDCXX}" = "y" ]; then
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
        extra_config+=("--with-gmp=${CT_COMPLIBS_DIR}")
        extra_config+=("--with-mpfr=${CT_COMPLIBS_DIR}")
    fi
    if [ "${CT_CC_GCC_USE_MPC}" = "y" ]; then
        extra_config+=("--with-mpc=${CT_COMPLIBS_DIR}")
    fi
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-ppl=${CT_COMPLIBS_DIR}")
        # With PPL 0.11+, also pull libpwl if needed
        if [ "${CT_PPL_NEEDS_LIBPWL}" = "y" ]; then
            host_libstdcxx_flags+=("-L${CT_COMPLIBS_DIR}/lib")
            host_libstdcxx_flags+=("-lpwl")
        fi
        extra_config+=("--with-cloog=${CT_COMPLIBS_DIR}")
    elif [ "${CT_CC_GCC_HAS_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-ppl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--with-libelf=${CT_COMPLIBS_DIR}")
        extra_config+=("--enable-lto")
    elif [ "${CT_CC_GCC_HAS_LTO}" = "y" ]; then
        extra_config+=("--with-libelf=no")
        extra_config+=("--disable-lto")
    fi

    if [ ${#host_libstdcxx_flags[@]} -ne 0 ]; then
        extra_config+=("--with-host-libstdcxx=${host_libstdcxx_flags[*]}")
    fi

    if [ "${CT_CC_GCC_ENABLE_TARGET_OPTSPACE}" = "y" ]; then
        extra_config+=("--enable-target-optspace")
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

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532)
    CT_DoExecLog CFG                                \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    LDFLAGS="${core_LDFLAGS[*]}"                    \
    "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/configure"  \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix="${core_prefix_dir}"               \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-multilib                          \
        --disable-libmudflap                        \
        ${CC_CORE_SYSROOT_ARG}                      \
        "${extra_config[@]}"                        \
        --disable-nls                               \
        --enable-languages="${lang_opt}"            \
        "${CT_CC_CORE_EXTRA_CONFIG_ARRAY[@]}"

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
        if [ ! -f "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/gcc/BASE-VER" ]; then
            CT_DoExecLog CFG make configure-libiberty
            CT_DoExecLog ALL make ${JOBSFLAGS} -C libiberty libiberty.a
            CT_DoExecLog CFG make configure-gcc configure-libcpp
            CT_DoExecLog ALL make ${JOBSFLAGS} all-libcpp
        else
            CT_DoExecLog CFG make configure-gcc configure-libcpp configure-build-libiberty
            CT_DoExecLog ALL make ${JOBSFLAGS} all-libcpp all-build-libiberty
        fi
        # HACK: gcc-4.2 uses libdecnumber to build libgcc.mk, so build it here.
        if [ -d "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/libdecnumber" ]; then
            CT_DoExecLog CFG make configure-libdecnumber
            CT_DoExecLog ALL make ${JOBSFLAGS} -C libdecnumber libdecnumber.a
        fi

        # Starting with GCC 4.3, libgcc.mk is no longer built,
        # and libgcc.mvars is used instead.

        if [ "${CT_CC_GCC_4_3_or_later}" = "y" ]; then
            libgcc_rule="libgcc.mvars"
            core_targets=( gcc target-libgcc )
        else
            libgcc_rule="libgcc.mk"
            core_targets=( gcc )
        fi

        # On bare metal and canadian build the host-compiler is used when
        # actually the build-system compiler is required. Choose the correct
        # compilers for canadian build and use the defaults on other
        # configurations.
        if [ "${CT_BARE_METAL},${CT_CANADIAN}" = "y,y" ]; then
            repair_cc="CC_FOR_BUILD=${CT_BUILD}-gcc \
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

    CT_DoLog EXTRA "Building ${mode} core C compiler"
    CT_DoExecLog ALL make ${JOBSFLAGS} "${core_targets[@]/#/all-}"

    CT_DoLog EXTRA "Installing ${mode} core C compiler"
    CT_DoExecLog ALL make "${core_targets[@]/#/install-}"

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-gcc to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${core_prefix_dir}/bin/${CT_TARGET}-gcc."* 2>/dev/null || true )"
    [ -z "${file}" ] || ext=".${file##*.}"
    CT_DoExecLog ALL ln -sv "${CT_TARGET}-gcc${ext}" "${core_prefix_dir}/bin/${CT_TARGET}-cc${ext}"

    CT_EndStep
}

#------------------------------------------------------------------------------
# Build final gcc
do_cc() {
    local -a host_libstdcxx_flags
    local -a extra_config
    local -a final_LDFLAGS
    local tmp

    # If building for bare metal, nothing to be done here, the static core conpiler is enough!
    [ "${CT_BARE_METAL}" = "y" ] && return 0

    CT_DoStep INFO "Installing final compiler"

    mkdir -p "${CT_BUILD_DIR}/build-cc"
    cd "${CT_BUILD_DIR}/build-cc"

    CT_DoLog EXTRA "Configuring final compiler"

    # Enable selected languages
    lang_opt="c"
    [ "${CT_CC_LANG_CXX}" = "y"      ] && lang_opt="${lang_opt},c++"
    [ "${CT_CC_LANG_FORTRAN}" = "y"  ] && lang_opt="${lang_opt},fortran"
    [ "${CT_CC_LANG_ADA}" = "y"      ] && lang_opt="${lang_opt},ada"
    [ "${CT_CC_LANG_JAVA}" = "y"     ] && lang_opt="${lang_opt},java"
    [ "${CT_CC_LANG_OBJC}" = "y"     ] && lang_opt="${lang_opt},objc"
    [ "${CT_CC_LANG_OBJCXX}" = "y"   ] && lang_opt="${lang_opt},obj-c++"
    CT_Test "Building ADA language is not yet supported. Will try..." "${CT_CC_LANG_ADA}" = "y"
    CT_Test "Building Objective-C language is not yet supported. Will try..." "${CT_CC_LANG_OBJC}" = "y"
    CT_Test "Building Objective-C++ language is not yet supported. Will try..." "${CT_CC_LANG_OBJCXX}" = "y"
    CT_Test "Building ${CT_CC_LANG_OTHERS//,/ } language(s) is not yet supported. Will try..." -n "${CT_CC_LANG_OTHERS}"
    lang_opt=$(echo "${lang_opt},${CT_CC_LANG_OTHERS}" |sed -r -e 's/,+/,/g; s/,*$//;')

    extra_config+=("--enable-languages=${lang_opt}")
    extra_config+=("--disable-multilib")
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
    if [ -n "${CT_CC_ENABLE_CXX_FLAGS}" ]; then
        extra_config+=("--enable-cxx-flags=${CT_CC_ENABLE_CXX_FLAGS}")
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

    # *** WARNING ! ***
    # Keep this full if-else-if-elif-fi-fi block in sync
    # with the same block in do_cc_core, above.
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
        if [ "${CT_CC_STATIC_LIBSTDCXX}" = "y" ]; then
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
        extra_config+=("--with-gmp=${CT_COMPLIBS_DIR}")
        extra_config+=("--with-mpfr=${CT_COMPLIBS_DIR}")
    fi
    if [ "${CT_CC_GCC_USE_MPC}" = "y" ]; then
        extra_config+=("--with-mpc=${CT_COMPLIBS_DIR}")
    fi
    if [ "${CT_CC_GCC_USE_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-ppl=${CT_COMPLIBS_DIR}")
        # With PPL 0.11+, also pull libpwl if needed
        if [ "${CT_PPL_NEEDS_LIBPWL}" = "y" ]; then
            host_libstdcxx_flags+=("-L${CT_COMPLIBS_DIR}/lib")
            host_libstdcxx_flags+=("-lpwl")
        fi
        extra_config+=("--with-cloog=${CT_COMPLIBS_DIR}")
    elif [ "${CT_CC_GCC_HAS_GRAPHITE}" = "y" ]; then
        extra_config+=("--with-ppl=no")
        extra_config+=("--with-cloog=no")
    fi
    if [ "${CT_CC_GCC_USE_LTO}" = "y" ]; then
        extra_config+=("--with-libelf=${CT_COMPLIBS_DIR}")
    elif [ "${CT_CC_GCC_HAS_LTO}" = "y" ]; then
        extra_config+=("--with-libelf=no")
    fi

    if [ ${#host_libstdcxx_flags[@]} -ne 0 ]; then
        extra_config+=("--with-host-libstdcxx=${host_libstdcxx_flags[*]}")
    fi

    if [ "${CT_THREADS}" = "none" ]; then
        extra_config+=("--disable-threads")
        if [ "${CT_CC_GCC_4_2_or_later}" = y ]; then
            CT_Test "Disabling libgomp for no-thread gcc>=4.2" "${CT_CC_GCC_LIBGOMP}" = "Y"
            extra_config+=("--disable-libgomp")
        fi
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

    if [ "${CT_CC_GCC_ENABLE_PLUGINS}" = "y" ]; then
        extra_config+=( --enable-plugin )
    fi
    if [ "${CT_CC_GCC_GOLD}" = "y" ]; then
        extra_config+=( --enable-gold )
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    # --disable-nls to work around crash bug on ppc405, but also because
    # embedded systems don't really need message catalogs...
    CT_DoExecLog CFG                                \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                  \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    LDFLAGS="${final_LDFLAGS[*]}"                   \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"         \
    CXXFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"       \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"       \
    "${CT_SRC_DIR}/gcc-${CT_CC_VERSION}/configure"  \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix="${CT_PREFIX_DIR}"                 \
        ${CC_SYSROOT_ARG}                           \
        "${extra_config[@]}"                        \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-nls                               \
        --enable-c99                                \
        --enable-long-long                          \
        "${CT_CC_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${JOBSFLAGS} all-build-libiberty
    fi

    CT_DoLog EXTRA "Building final compiler"
    CT_DoExecLog ALL make ${JOBSFLAGS} all

    CT_DoLog EXTRA "Installing final compiler"
    CT_DoExecLog ALL make install

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-gcc to always be able
    # to call the C compiler with the same, somewhat canonical name.
    # check whether compiler has an extension
    file="$( ls -1 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-gcc."* 2>/dev/null || true )"
    [ -z "${file}" ] || ext=".${file##*.}"
    CT_DoExecLog ALL ln -sv "${CT_TARGET}-gcc${ext}" "${CT_PREFIX_DIR}/bin/${CT_TARGET}-cc${ext}"

    CT_EndStep
}
