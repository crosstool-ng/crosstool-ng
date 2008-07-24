# This file adds the function to build the gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() {
    [ "${CT_CC}" = "gcc" ] || return 0
    echo "gcc-${CT_CC_VERSION}"
}

# Download gcc
do_cc_get() {
    # Ah! gcc folks are kind of 'different': they store the tarballs in
    # subdirectories of the same name! That's because gcc is such /crap/ that
    # it is such /big/ that it needs being splitted for distribution! Sad. :-(
    # Arrgghh! Some of those versions does not follow this convention:
    # gcc-3.3.3 lives in releases/gcc-3.3.3, while gcc-2.95.* isn't in a
    # subdirectory! You bastard!
    CT_GetFile "${CT_CC_FILE}"  \
               {ftp,http}://ftp.gnu.org/gnu/gcc{,{,/releases}/${CT_CC_FILE}}
}

# Extract gcc
do_cc_extract() {
    CT_ExtractAndPatch "${CT_CC_FILE}"
}

#------------------------------------------------------------------------------
# Core gcc pass 1
do_cc_core_pass_1() {
    # In case we're NPTL, build the static core gcc;
    # in any other case, do nothing.
    case "${CT_THREADS}" in
        nptl)   do_cc_core_static;;
    esac
}

# Core gcc pass 2
do_cc_core_pass_2() {
    # In case we're NPTL, build the shared core gcc,
    # in any other case, build the static core gcc.
    case "${CT_THREADS}" in
        nptl)   do_cc_core_shared;;
        *)      do_cc_core_static;;
    esac
}

#------------------------------------------------------------------------------
# Build static core gcc
do_cc_core_static() {
    mkdir -p "${CT_BUILD_DIR}/build-cc-core-static"
    cd "${CT_BUILD_DIR}/build-cc-core-static"

    CT_DoStep INFO "Installing static core C compiler"

    CT_DoLog DEBUG "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/include"
    cp -r "${CT_HEADERS_DIR}"/* "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/include" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Configuring static core C compiler"

    extra_config="${CT_ARCH_WITH_ARCH} ${CT_ARCH_WITH_ABI} ${CT_ARCH_WITH_CPU} ${CT_ARCH_WITH_TUNE} ${CT_ARCH_WITH_FPU} ${CT_ARCH_WITH_FLOAT}"
    [ "${CT_GMP_MPFR}" = "y" ] && extra_config="${extra_config} --with-gmp=${CT_PREFIX_DIR} --with-mpfr=${CT_PREFIX_DIR}"
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config="${extra_config} --enable-__cxa_atexit"
    else
        extra_config="${extra_config} --disable-__cxa_atexit"
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config}'"

    # Use --with-local-prefix so older gccs don't look in /usr/local (http://gcc.gnu.org/PR10532)
    CC_FOR_BUILD="${CT_CC_NATIVE}"                  \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CT_DoExecLog ALL                                \
    "${CT_SRC_DIR}/${CT_CC_FILE}/configure"         \
        ${CT_CANADIAN_OPT}                          \
        --host=${CT_HOST}                           \
        --target=${CT_TARGET}                       \
        --prefix="${CT_CC_CORE_STATIC_PREFIX_DIR}"  \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-multilib                          \
        --with-newlib                               \
        ${CC_CORE_SYSROOT_ARG}                      \
        ${extra_config}                             \
        --disable-nls                               \
        --enable-threads=no                         \
        --enable-symvers=gnu                        \
        --enable-languages=c                        \
        --disable-shared                            \
        --enable-target-optspace                    \
        ${CT_CC_CORE_EXTRA_CONFIG}

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} all-build-libiberty
    fi

    CT_DoLog EXTRA "Building static core C compiler"
    CT_DoExecLog ALL make ${PARALLELMFLAGS} all-gcc

    CT_DoLog EXTRA "Installing static core C compiler"
    CT_DoExecLog ALL make install-gcc

    CT_EndStep
}

#------------------------------------------------------------------------------
# Build shared core gcc
do_cc_core_shared() {
    mkdir -p "${CT_BUILD_DIR}/build-cc-core-shared"
    cd "${CT_BUILD_DIR}/build-cc-core-shared"

    CT_DoStep INFO "Installing shared core C compiler"

    CT_DoLog DEBUG "Copying headers to install area of bootstrap gcc, so it can build libgcc2"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/include"
    cp -r "${CT_HEADERS_DIR}"/* "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/include" 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Configuring shared core C compiler"

    extra_config="${CT_ARCH_WITH_ARCH} ${CT_ARCH_WITH_ABI} ${CT_ARCH_WITH_CPU} ${CT_ARCH_WITH_TUNE} ${CT_ARCH_WITH_FPU} ${CT_ARCH_WITH_FLOAT}"
    [ "${CT_GMP_MPFR}" = "y" ] && extra_config="${extra_config} --with-gmp=${CT_PREFIX_DIR} --with-mpfr=${CT_PREFIX_DIR}"
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config="${extra_config} --enable-__cxa_atexit"
    else
        extra_config="${extra_config} --disable-__cxa_atexit"
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config}'"

    CC_FOR_BUILD="${CT_CC_NATIVE}"                  \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CT_DoExecLog ALL                                \
    "${CT_SRC_DIR}/${CT_CC_FILE}/configure"         \
        ${CT_CANADIAN_OPT}                          \
        --target=${CT_TARGET}                       \
        --host=${CT_HOST}                           \
        --prefix="${CT_CC_CORE_SHARED_PREFIX_DIR}"  \
        --with-local-prefix="${CT_SYSROOT_DIR}"     \
        --disable-multilib                          \
        ${CC_CORE_SYSROOT_ARG}                      \
        ${extra_config}                             \
        --disable-nls                               \
        --enable-symvers=gnu                        \
        --enable-languages=c                        \
        --enable-shared                             \
        --enable-target-optspace                    \
        ${CT_CC_CORE_EXTRA_CONFIG}

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
    if [ ! -f "${CT_SRC_DIR}/${CT_CC_FILE}/gcc/BASE-VER" ]; then
        CT_DoExecLog ALL make configure-libiberty
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -C libiberty libiberty.a
        CT_DoExecLog ALL make configure-gcc configure-libcpp
        CT_DoExecLog ALL make ${PARALLELMFLAGS} all-libcpp
    else
        CT_DoExecLog ALL make configure-gcc configure-libcpp configure-build-libiberty
        CT_DoExecLog ALL make ${PARALLELMFLAGS} all-libcpp all-build-libiberty
    fi
    # HACK: gcc-4.2 uses libdecnumber to build libgcc.mk, so build it here.
    if [ -d "${CT_SRC_DIR}/${CT_CC_FILE}/libdecnumber" ]; then
        CT_DoExecLog ALL make configure-libdecnumber
        CT_DoExecLog ALL make ${PARALLELMFLAGS} -C libdecnumber libdecnumber.a
    fi

    # Starting with GCC 4.3, libgcc.mk is no longer built,
    # and libgcc.mvars is used instead.

    gcc_version_major=$(echo ${CT_CC_VERSION} |sed -r -e 's/^([^\.]+)\..*/\1/')
    gcc_version_minor=$(echo ${CT_CC_VERSION} |sed -r -e 's/^[^\.]+\.([^.]+).*/\1/')

    if [    ${gcc_version_major} -eq 4 -a ${gcc_version_minor} -ge 3    \
         -o ${gcc_version_major} -gt 4                                  ]; then
        libgcc_rule="libgcc.mvars"
        build_rules="all-gcc all-target-libgcc"
        install_rules="install-gcc install-target-libgcc"
    else
        libgcc_rule="libgcc.mk"
        build_rules="all-gcc"
        install_rules="install-gcc"
    fi

    CT_DoExecLog ALL make -C gcc ${libgcc_rule}
    sed -r -i -e 's@-lc@@g' gcc/${libgcc_rule}

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} all-build-libiberty
    fi

    CT_DoLog EXTRA "Building shared core C compiler"
    CT_DoExecLog ALL make ${PARALLELMFLAGS} ${build_rules}

    CT_DoLog EXTRA "Installing shared core C compiler"
    CT_DoExecLog ALL make ${install_rules}

    CT_EndStep
}

#------------------------------------------------------------------------------
# Build final gcc
do_cc() {
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

    extra_config="--enable-languages=${lang_opt}"
    extra_config="${extra_config} --disable-multilib"
    extra_config="${extra_config} ${CT_ARCH_WITH_ARCH} ${CT_ARCH_WITH_ABI} ${CT_ARCH_WITH_CPU} ${CT_ARCH_WITH_TUNE} ${CT_ARCH_WITH_FPU} ${CT_ARCH_WITH_FLOAT}"
    [ "${CT_SHARED_LIBS}" = "y" ]     || extra_config="${extra_config} --disable-shared"
    [ "${CT_GMP_MPFR}" = "y" ] && extra_config="${extra_config} --with-gmp=${CT_PREFIX_DIR} --with-mpfr=${CT_PREFIX_DIR}"
    [ -n "${CT_CC_PKGVERSION}" ]      && extra_config="${extra_config} --with-pkgversion=${CT_CC_PKGVERSION}"
    [ -n "${CT_CC_BUGURL}" ]          && extra_config="${extra_config} --with-bugurl=${CT_CC_BUGURL}"
    if [ "${CT_CC_CXA_ATEXIT}" = "y" ]; then
        extra_config="${extra_config} --enable-__cxa_atexit"
    else
        extra_config="${extra_config} --disable-__cxa_atexit"
    fi

    CT_DoLog DEBUG "Extra config passed: '${extra_config}'"

    # --enable-symvers=gnu really only needed for sh4 to work around a
    # detection problem only matters for gcc-3.2.x and later, I think.
    # --disable-nls to work around crash bug on ppc405, but also because
    # embedded systems don't really need message catalogs...
    CC_FOR_BUILD="${CT_CC_NATIVE}"              \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"              \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"     \
    CXXFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"   \
    LDFLAGS_FOR_TARGET="${CT_TARGET_LDFLAGS}"   \
    CT_DoExecLog ALL                            \
    "${CT_SRC_DIR}/${CT_CC_FILE}/configure"     \
        ${CT_CANADIAN_OPT}                      \
        --target=${CT_TARGET} --host=${CT_HOST} \
        --prefix="${CT_PREFIX_DIR}"             \
        ${CC_SYSROOT_ARG}                       \
        ${extra_config}                         \
        --with-local-prefix="${CT_SYSROOT_DIR}" \
        --disable-nls                           \
        --enable-threads=posix                  \
        --enable-symvers=gnu                    \
        --enable-c99                            \
        --enable-long-long                      \
        --enable-target-optspace                \
        ${CT_CC_EXTRA_CONFIG}

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        CT_DoExecLog ALL make ${PARALLELMFLAGS} all-build-libiberty
    fi

    # Idea from <cort.dougan at gmail.com>:
    # Fix lib/lib64 confusion for GCC 3.3.3 on PowerPC64 and x86_64.
    # GCC 3.4.0 and up don't suffer from this confusion, and don't need this
    # kludge.
    # FIXME: we should patch gcc's source rather than uglify crosstool.sh.
    # FIXME: is this needed for gcc-3.3.[56]?
    case "${CT_CC_FILE}" in
      gcc-3.3.[34])
        case "${CT_TARGET}" in
          powerpc64-unknown-linux-gnu|x86_64-unknown-linux-gnu)
            for d in $(find "${CT_SYSROOT_DIR}" -name lib -type d -empty); do
              if [ -d $(dirname "${d}")/lib64 ] ; then
                rm -rf "${d}"
                ln -s $(dirname "${d}")/lib64 "${d}"
              fi
            done ;;
          *) ;;
        esac ;;
    esac

    CT_DoLog EXTRA "Building final compiler"
    CT_DoExecLog ALL make ${PARALLELMFLAGS} all

    CT_DoLog EXTRA "Installing final compiler"
    CT_DoExecLog ALL make install

    # Create a symlink ${CT_TARGET}-cc to ${CT_TARGET}-gcc to always be able
    # to call the C compiler with the same, somewhat canonical name.
    ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}"-{g,}cc 2>&1 |CT_DoLog ALL

    # gcc installs stuff in prefix/target/lib, when it would make better sense
    # to install that into sysroot/usr/lib
    CT_DoLog EXTRA "Moving improperly installed gcc libs to sysroot"
    ( cd "${CT_PREFIX_DIR}/${CT_TARGET}/lib"; tar cf - . ) | ( cd "${CT_SYSROOT_DIR}/usr/lib"; tar xfv - ) |CT_DoLog ALL
    rm -rf "${CT_PREFIX_DIR}/${CT_TARGET}/lib"

    CT_EndStep
}
