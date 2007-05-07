# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download glibc
do_libc_get() {
    # Ah! Not all GNU folks seem stupid. All glibc releases are in the same
    # directory. Good. Alas, there is no snapshot there. I'll deal with them
    # later on... :-/
    CT_GetFile "${CT_LIBC_FILE}" ftp://ftp.gnu.org/gnu/glibc

    # C library addons
    addons_list=`echo "${CT_LIBC_ADDONS}" |sed -r -e 's/,/ /g; s/ $//g;'`
    for addon in ${addons_list}; do
        CT_GetFile "${CT_LIBC}-${addon}-${CT_LIBC_VERSION}" ftp://ftp.gnu.org/gnu/glibc
    done
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && CT_GetFile "${CT_LIBC}-ports-${CT_LIBC_VERSION}" ftp://ftp.gnu.org/gnu/glibc

    return 0
}

# Extract glibc
do_libc_extract() {
    CT_ExtractAndPatch "${CT_LIBC_FILE}"

    # C library addons
    addons_list=`echo "${CT_LIBC_ADDONS}" |sed -r -e 's/,/ /g; s/ $//g;'`
    for addon in ${addons_list}; do
        CT_ExtractAndPatch "${CT_LIBC}-${addon}-${CT_LIBC_VERSION}"
    done
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && CT_ExtractAndPatch "${CT_LIBC}-ports-${CT_LIBC_VERSION}"

    return 0
}

# There is nothing to do for glibc check config
do_libc_check_config() {
    CT_DoStep INFO "Checking C library configuration"
    CT_DoLog EXTRA "glibc has nothing to check"
    CT_EndStep
}

# This function installs the glibc headers needed to build the core compiler
do_libc_headers() {
    # Only need to install bootstrap glibc headers for gcc-3.0 and above?  Or maybe just gcc-3.3 and above?
    # See also http://gcc.gnu.org/PR8180, which complains about the need for this step.
    grep -q 'gcc-[34]' "${CT_SRC_DIR}/${CT_CC_CORE_FILE}/ChangeLog" || return 0

    CT_DoStep INFO "Installing C library headers"

    mkdir -p "${CT_BUILD_DIR}/build-libc-headers"
    cd "${CT_BUILD_DIR}/build-libc-headers"

    CT_DoLog EXTRA "Configuring C library headers"

    # The following three things have to be done to build glibc-2.3.x, but they don't hurt older versions.
    # 1. override CC to keep glibc's configure from using $TARGET-gcc. 
    # 2. disable linuxthreads, which needs a real cross-compiler to generate tcb-offsets.h properly
    # 3. build with gcc 3.2 or later
    # Compare these options with the ones used when building glibc for real below - they're different.
    # As of glibc-2.3.2, to get this step to work for hppa-linux, you need --enable-hacker-mode
    # so when configure checks to make sure gcc has access to the assembler you just built...
    # Alternately, we could put ${PREFIX}/${TARGET}/bin on the path.
    # Set --build so maybe we don't have to specify "cross-compiling=yes" below (haven't tried yet)
    # Note: the warning
    # "*** WARNING: Are you sure you do not want to use the `linuxthreads'"
    # *** add-on?"
    # is ok here, since all we want are the basic headers at this point.
    # Override libc_cv_ppc_machine so glibc-cvs doesn't complain
    # 'a version of binutils that supports .machine "altivec" is needed'.
    libc_cv_ppc_machine=yes                     \
    CC=${CT_CC_NATIVE}                          \
    "${CT_SRC_DIR}/${CT_LIBC_FILE}/configure"   \
        --build="${CT_BUILD}"                   \
        --host="${CT_TARGET}"                   \
        --prefix=/usr                           \
        --with-headers="${CT_HEADERS_DIR}"      \
        --without-cvs                           \
        --disable-sanity-checks                 \
        --enable-hacker-mode                    \
        --enable-add-ons=""                     \
        --without-nptl                          2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Installing C library headers"

    if grep -q GLIBC_2.3 "${CT_SRC_DIR}/${CT_LIBC_FILE}/ChangeLog"; then
        # glibc-2.3.x passes cross options to $(CC) when generating errlist-compat.c,
        # which fails without a real cross-compiler.
        # Fortunately, we don't need errlist-compat.c, since we just need .h
        # files, so work around this by creating a fake errlist-compat.c and
        # satisfying its dependencies.
        # Another workaround might be to tell configure to not use any cross
        # options to $(CC).
        # The real fix would be to get install-headers to not generate
        # errlist-compat.c.
        # Note: BOOTSTRAP_GCC is used by:
        # patches/glibc-2.3.5/glibc-mips-bootstrap-gcc-header-install.patch
        libc_cv_ppc_machine=yes                             \
        make CFLAGS=-DBOOTSTRAP_GCC sysdeps/gnu/errlist.c   2>&1 |CT_DoLog DEBUG
        mkdir -p stdio-common
        # sleep for 2 seconds for benefit of filesystems with lousy time
        # resolution, like FAT, so make knows for sure errlist-compat.c doesn't
        # need generating
        sleep 2
        touch stdio-common/errlist-compat.c
    fi
    # Note: BOOTSTRAP_GCC (see above)
    libc_cv_ppc_machine=yes                                 \
    make cross-compiling=yes install_root=${CT_SYSROOT_DIR} \
        CFLAGS=-DBOOTSTRAP_GCC ${LIBC_SYSROOT_ARG}          \
        install-headers                                     2>&1 |CT_DoLog DEBUG

    # Two headers -- stubs.h and features.h -- aren't installed by install-headers,
    # so do them by hand.  We can tolerate an empty stubs.h for the moment.
    # See e.g. http://gcc.gnu.org/ml/gcc/2002-01/msg00900.html
    mkdir -p "${CT_HEADERS_DIR}/gnu"
    touch "${CT_HEADERS_DIR}/gnu/stubs.h"
    cp "${CT_SRC_DIR}/${CT_LIBC_FILE}/include/features.h" "${CT_HEADERS_DIR}/features.h"

    # Building the bootstrap gcc requires either setting inhibit_libc, or
    # having a copy of stdio_lim.h... see
    # http://sources.redhat.com/ml/libc-alpha/2003-11/msg00045.html
    cp bits/stdio_lim.h "${CT_HEADERS_DIR}/bits/stdio_lim.h"

    # Following error building gcc-4.0.0's gcj:
    #  error: bits/syscall.h: No such file or directory
    # solved by following copy; see http://sourceware.org/ml/crossgcc/2005-05/msg00168.html
    # but it breaks arm, see http://sourceware.org/ml/crossgcc/2006-01/msg00091.html
    [ "${CT_ARCH}" != "arm" ] && cp misc/syscall-list.h "${CT_HEADERS_DIR}/bits/syscall.h" || true

    CT_EndStep
}

# This function builds and install the full glibc
do_libc() {
    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Add some default glibc config options if not given by user.
    extra_config=""
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
        *enable-kernel*) ;;
        *) extra_config="${extra_config} --enable-kernel=${CT_KERNEL_VERSION}"
    esac
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
        *-tls*) ;;
        *) extra_config="${extra_config} --without-tls"
    esac
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
        *-__thread*) ;;
        *) extra_config="${extra_config} --without-__thread"
    esac
    case "${CT_SHARED_LIBS}" in
        y) extra_config="${extra_config} --enable-shared";;
        *) extra_config="${extra_config} --disable-shared";;
    esac
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
    	*--with-fp*) ;;
    	*--without-fp*) ;;
    	*)  case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
                y,) extra_config="${extra_config} --with-fp";;
                ,y) extra_config="${extra_config} --without-fp";;
            esac;;
    esac
    case "${CT_LIBC_ADDONS},${CT_LIBC_ADDONS_LIST}" in
        y,) extra_config="${extra_config} --enable-add-ons";;
        y,*) extra_config="${extra_config} --enable-add-ons=${CT_LIBC_ADDONS_LIST}";;
    esac

    CT_DoLog DEBUG "Extra config args passed: \"${extra_config}\""

    # Add some default CC args
    extra_cc_args="${CT_CFLAGS_FOR_HOST}"
    case "${CT_LIBC_EXTRA_CC_ARGS}" in
        *-mbig-endian*) ;;
        *-mlittle-endian*) ;;
        *)  case "${CT_ARCH_BE},${CT_ARCH_LE}" in
                y,) extra_cc_args="${extra_cc_args} -mbig-endian";;
                ,y) extra_cc_args="${extra_cc_args} -mlittle-endian";;
            esac;;
    esac

    CT_DoLog DEBUG "Extra CC args passed: \"${extra_cc_args}\""

    # sh3 and sh4 really need to set configparms as of gcc-3.4/glibc-2.3.2
    # note: this is awkward, doesn't work well if you need more than one line in configparms
    echo ${CT_LIBC_GLIBC_CONFIGPARMS} > configparms

    # For glibc 2.3.4 and later we need to set some autoconf cache
    # variables, because nptl/sysdeps/pthread/configure.in does not
    # work when cross-compiling.
    if test -d ${GLIBC_DIR}/nptl; then
        libc_cv_forced_unwind=yes
        libc_cv_c_cleanup=yes
        export libc_cv_forced_unwind libc_cv_c_cleanup
    fi

    # Configure with --prefix the way we want it on the target...
    # There are a whole lot of settings here.  You'll probably want
    # to read up on what they all mean, and customize a bit, possibly by setting GLIBC_EXTRA_CONFIG
    # Compare these options with the ones used when installing the glibc headers above - they're different.
    # Adding "--without-gd" option to avoid error "memusagestat.c:36:16: gd.h: No such file or directory" 
    # See also http://sources.redhat.com/ml/libc-alpha/2000-07/msg00024.html. 
    # Set BUILD_CC, or you won't be able to build datafiles
    # Set --build, else glibc-2.3.2 will think you're not cross-compiling, and try to run the test programs

    BUILD_CC=${CT_CC_NATIVE}                                        \
    CFLAGS="${CT_TARGET_CFLAGS} ${CT_LIBC_GLIBC_EXTRA_CFLAGS} -O"   \
    CC="${CT_TARGET}-gcc ${CT_LIBC_EXTRA_CC_ARGS} ${extra_cc_args}" \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    "${CT_SRC_DIR}/${CT_LIBC_FILE}/configure"                       \
        --prefix=/usr                                               \
        --build=${CT_BUILD} --host=${CT_TARGET}                     \
        ${CT_LIBC_GLIBC_EXTRA_CONFIG}                               \
        ${extra_config}                                             \
        --without-cvs                                               \
        --disable-profile                                           \
        --disable-debug                                             \
        --without-gd                                                \
        --with-headers="${CT_HEADERS_DIR}"                          2>&1 |CT_DoLog DEBUG

    if grep -l '^install-lib-all:' "${CT_SRC_DIR}/${CT_LIBC_FILE}/Makerules" > /dev/null; then
        # nptl-era glibc.
        # If the install-lib-all target (which is added by our make-install-lib-all.patch)
        # is present, it means we're building glibc-2.3.3 or later, and we can't
        # build programs yet, as they require libeh, which won't be installed
        # until full build of gcc
        GLIBC_INITIAL_BUILD_RULE=lib
        GLIBC_INITIAL_INSTALL_RULE="install-lib-all install-headers"
        GLIBC_INSTALL_APPS_LATER=yes
    else
        # classic glibc.  
        # We can build and install everything with the bootstrap compiler.
        GLIBC_INITIAL_BUILD_RULE=all
        GLIBC_INITIAL_INSTALL_RULE=install
        GLIBC_INSTALL_APPS_LATER=no
    fi

    # If this fails with an error like this:
    # ...  linux/autoconf.h: No such file or directory 
    # then you need to set the KERNELCONFIG variable to point to a .config file for this arch.
    # The following architectures are known to need kernel .config: alpha, arm, ia64, s390, sh, sparc
    # Note: LD and RANLIB needed by glibc-2.1.3's c_stub directory, at least on macosx
    # No need for PARALLELMFLAGS here, Makefile already reads this environment variable
    CT_DoLog EXTRA "Building C library"
    make LD=${CT_TARGET}-ld             \
         RANLIB=${CT_TARGET}-ranlib     \
         ${GLIBC_INITIAL_BUILD_RULE}    2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Installing C library"
    make install_root="${CT_SYSROOT_DIR}"   \
         ${LIBC_SYSROOT_ARG}                \
         ${GLIBC_INITIAL_INSTALL_RULE}      2>&1 |CT_DoLog DEBUG

    # This doesn't seem to work when building a crosscompiler,
    # as it tries to execute localedef using the just-built ld.so!?
    #CT_DoLog EXTRA "Installing locales"
    #make localedata/install-locales install_root=${SYSROOT} 2>&1 |CT_DoLog DEBUG

    # Fix problems in linker scripts.
    #
    # 1. Remove absolute paths
    # Any file in a list of known suspects that isn't a symlink is assumed to be a linker script.
    # FIXME: test -h is not portable
    # FIXME: probably need to check more files than just these three...
    # Need to use sed instead of just assuming we know what's in libc.so because otherwise alpha breaks
    #
    # 2. Remove lines containing BUG per http://sources.redhat.com/ml/bug-glibc/2003-05/msg00055.html,
    # needed to fix gcc-3.2.3/glibc-2.3.2 targeting arm
    #
    # To make "strip *.so.*" not fail (ptxdist does this), rename to .so_orig rather than .so.orig
    CT_DoLog EXTRA "Fixing C library linker scripts"
    for file in libc.so libpthread.so libgcc_s.so; do
        for dir in lib lib64 usr/lib usr/lib64; do
            if [ -f "${CT_SYSROOT_DIR}/${dir}/${file}" -a ! -L ${CT_SYSROOT_DIR}/$lib/$file ]; then
                mv "${CT_SYSROOT_DIR}/${dir}/${file}" "${CT_SYSROOT_DIR}/${dir}/${file}_orig"
                CT_DoLog DEBUG "Fixing \"${CT_SYS_ROOT_DIR}/${dir}/${file}\""
                sed -i -r -e 's,/usr/lib/,,g;
                              s,/usr/lib64/,,g;
                              s,/lib/,,g;
                              s,/lib64/,,g;
                              /BUG in libc.scripts.output-format.sed/d' "${CT_SYSROOT_DIR}/${dir}/${file}_orig"
            fi
        done
    done

    CT_EndStep
}

# This function finishes the glibc install
do_libc_finish() {
    # Finally, build and install glibc programs, now that libeh (if any) is installed
    # Don't do this unless needed, 'cause it causes glibc-2.{1.3,2.2} to fail here with
    # .../gcc-3.4.1-glibc-2.1.3/build-glibc/libc.so.6: undefined reference to `__deregister_frame_info'
    # .../gcc-3.4.1-glibc-2.1.3/build-glibc/libc.so.6: undefined reference to `__register_frame_info'
    [ "${GLIBC_INSTALL_APPS_LATER}" = "yes" ] || return 0

    CT_DoStep INFO "Finishing C library"

    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Re-building C library"
    make LD=${CT_TARGET}-ld RANLIB=${CT_TARGET}-ranlib 2>&1 |CT_DoLog DEBUG

    CT_DoLog EXTRA "Installing missing C library components"
    # note: should do full install and then fix linker scripts, but this is faster
    for t in bin rootsbin sbin data others; do
        make install_root="${CT_SYSROOT_DIR}"   \
             ${LIBC_SYSROOT_ARG}                \
             install-${t}                       2>&1 |CT_DoLog DEBUG
    done
}
