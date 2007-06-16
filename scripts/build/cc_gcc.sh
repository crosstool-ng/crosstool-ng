# This file adds the function to build the final gcc C compiler
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_print_filename() {
    [ "${CT_CC}" = "gcc" ] || return 0
    echo "${CT_CC_FILE}"
}

# Download final gcc
do_cc_get() {
    # Ah! gcc folks are kind of 'different': they store the tarballs in
    # subdirectories of the same name! That's because gcc is such /crap/ that
    # it is such /big/ that it needs being splitted for distribution! Sad. :-(
    # Arrgghh! Some of those versions does not follow this convention:
    # gcc-3.3.3 lives in releases/gcc-3.3.3, while gcc-2.95.* isn't in a
    # subdirectory! You bastard!
    CT_GetFile "${CT_CC_FILE}"                                  \
               ftp://ftp.gnu.org/gnu/gcc/${CT_CC_FILE}          \
               ftp://ftp.gnu.org/gnu/gcc/releases/${CT_CC_FILE} \
               ftp://ftp.gnu.org/gnu/gcc
}

# Extract final gcc
do_cc_extract() {
    CT_ExtractAndPatch "${CT_CC_FILE}"
}

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
    CT_Test "Building Fortran language is not yet supported. Will try..." "${CT_CC_LANG_FORTRAN}" = "y"
    CT_Test "Building ADA language is not yet supported. Will try..." "${CT_CC_LANG_ADA}" = "y"
    CT_Test "Building Java language is not yet supported. Will try..." "${CT_CC_LANG_JAVA}" = "y"
    CT_Test "Building Objective-C language is not yet supported. Will try..." "${CT_CC_LANG_OBJC}" = "y"
    CT_Test "Building Objective-C++ language is not yet supported. Will try..." "${CT_CC_LANG_OBJCXX}" = "y"
    CT_Test "Building ${CT_CC_LANG_OTHERS} language(s) is not yet supported. Will try..." -n "${CT_CC_LANG_OTHERS}"
    lang_opt=`echo "${lang_opt},${CT_CC_LANG_OTHERS}" |sed -r -e 's/,+/,/g; s/,*$//;'`

    extra_config="--enable-languages=${lang_opt}"
    [ "${CT_ARCH_FLOAT_SW}" = "y" ] && extra_config="${extra_config} --with-float=soft"
    [ "${CT_SHARED_LIBS}" = "y" ] || extra_config="${extra_config} --disable-shared"
    [ -n "${CT_ARCH_ABI}" ]  && extra_config="${extra_config} --with-abi=${CT_ARCH_ABI}"
    [ -n "${CT_ARCH_CPU}" ]  && extra_config="${extra_config} --with-cpu=${CT_ARCH_CPU}"
    [ -n "${CT_ARCH_TUNE}" ] && extra_config="${extra_config} --with-tune=${CT_ARCH_TUNE}"
    [ -n "${CT_ARCH_ARCH}" ] && extra_config="${extra_config} --with-arch=${CT_ARCH_ARCH}"
    [ -n "${CT_ARCH_FPU}" ] && extra_config="${extra_config} --with-fpu=${CT_ARCH_FPU}"
    if [ "${CT_TARGET_MULTILIB}" = "y" ]; then
       extra_config="${extra_config} --enable-multilib"
    else
       extra_config="${extra_config} --disable-multilib"
    fi
    [ "${CT_CC_CXA_ATEXIT}" == "y" ] && extra_config="${extra_config} --enable-__cxa_atexit"

    CT_DoLog DEBUG "Extra config passed: \"${extra_config}\""

    # --enable-symvers=gnu really only needed for sh4 to work around a
    # detection problem only matters for gcc-3.2.x and later, I think.
    # --disable-nls to work around crash bug on ppc405, but also because
    # embedded systems don't really need message catalogs...
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
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
        ${CT_CC_EXTRA_CONFIG}                   2>&1 |CT_DoLog ALL

    if [ "${CT_CANADIAN}" = "y" ]; then
        CT_DoLog EXTRA "Building libiberty"
        make ${PARALLELMFLAGS} all-build-libiberty 2>&1 |CT_DoLog ALL
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
            for d in `find "${CT_SYSROOT_DIR}" -name lib -type d -empty`; do
              if [ -d `dirname "${d}"`/lib64 ] ; then
                rm -rf "${d}"
                ln -s `dirname "${d}"`/lib64 "${d}"
              fi
            done ;;
          *) ;;
        esac ;;
    esac

    CT_DoLog EXTRA "Building final compiler"
    make ${PARALLELMFLAGS} all 2>&1 |CT_DoLog ALL

    CT_DoLog EXTRA "Installing final compiler"
    make install 2>&1 |CT_DoLog ALL

    # FIXME: shouldn't people who want this just --disable-multilib in final gcc
    # and be done with it?
    # This code should probably be deleted, it was written long ago and hasn't
    # been tested in ages.
    # kludge: If the chip does not have a floating point unit
    # (i.e. if GLIBC_EXTRA_CONFIG contains --without-fp),
    # and there are shared libraries in /lib/nof, copy them to /lib
    # so they get used by default.
    # FIXME: only rs6000/powerpc seem to use nof.  See MULTILIB_DIRNAMES
    # in $GCC_DIR/gcc/config/$TARGET/* to see what your arch calls it.
    #case "${CT_LIBC_EXTRA_CONFIG}" in
    #    *--without-fp*)
    #        if test -d "${CT_SYSROOT_DIR}/lib/nof"; then
    #            cp -af "${CT_SYSROOT_DIR}/lib/nof/"*.so* "${CT_SYSROOT_DIR}/lib" || true
    #        fi
    #    ;;
    #esac

    CT_EndStep
}
