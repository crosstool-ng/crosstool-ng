# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download glibc
do_libc_get() {
    local date
    local version
    local -a addons_list

    addons_list=($(do_libc_add_ons_list " "))

    # Main source
    CT_GetFile "glibc-${CT_LIBC_VERSION}"               \
               {ftp,http}://ftp.gnu.org/gnu/glibc       \
               ftp://gcc.gnu.org/pub/glibc/releases     \
               ftp://gcc.gnu.org/pub/glibc/snapshots

    # C library addons
    for addon in "${addons_list[@]}"; do
        # NPTL addon is not to be downloaded, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_GetFile "glibc-${addon}-${CT_LIBC_VERSION}"      \
                   {ftp,http}://ftp.gnu.org/gnu/glibc       \
                   ftp://gcc.gnu.org/pub/glibc/releases     \
                   ftp://gcc.gnu.org/pub/glibc/snapshots
    done

    return 0
}

# Extract glibc
do_libc_extract() {
    local -a addons_list

    addons_list=($(do_libc_add_ons_list " "))

    CT_Extract "glibc-${CT_LIBC_VERSION}"

    CT_Pushd "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}"
    CT_Patch nochdir "glibc" "${CT_LIBC_VERSION}"

    # C library addons
    for addon in "${addons_list[@]}"; do
        # NPTL addon is not to be extracted, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_Extract nochdir "glibc-${addon}-${CT_LIBC_VERSION}"

        # Some addons have the 'long' name, while others have the
        # 'short' name, but patches are non-uniformly built with
        # either the 'long' or 'short' name, whatever the addons name
        # so we have to make symlinks from the existing to the missing
        # Fortunately for us, [ -d foo ], when foo is a symlink to a
        # directory, returns true!
        [ -d "${addon}" ] || CT_DoExecLog ALL ln -s "glibc-${addon}-${CT_LIBC_VERSION}" "${addon}"
        [ -d "glibc-${addon}-${CT_LIBC_VERSION}" ] || CT_DoExecLog ALL ln -s "${addon}" "glibc-${addon}-${CT_LIBC_VERSION}"
        CT_Patch nochdir "glibc" "${addon}-${CT_LIBC_VERSION}"
    done

    # The configure files may be older than the configure.in files
    # if using a snapshot (or even some tarballs). Fake them being
    # up to date.
    sleep 2
    find . -type f -name configure -exec touch {} \; 2>&1 |CT_DoLog ALL

    CT_Popd

    return 0
}

# There is nothing to do for glibc check config
do_libc_check_config() {
    :
}

# This function installs the glibc headers needed to build the core compiler
do_libc_headers() {
    local -a extra_config
    local arch4hdrs

    CT_DoStep INFO "Installing C library headers"

    mkdir -p "${CT_BUILD_DIR}/build-libc-headers"
    cd "${CT_BUILD_DIR}/build-libc-headers"

    CT_DoLog EXTRA "Configuring C library"

    # The x86 arch needs special care... Bizarelly enough... :-(
    case "${CT_ARCH}:${CT_ARCH_BITNESS}" in
        x86:32) arch4hdrs="i386";;
        x86:64) arch4hdrs="x86_64";;
        *)      arch4hdrs="${CT_ARCH}";;
    esac

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

    # We need to remove any threading addon when installing headers
    addons_list="$(do_libc_add_ons_list " "                     \
                   |sed -r -e 's/\<(nptl|linuxthreads)\>/ /g;'  \
                           -e 's/ +/,/g; s/^,+//; s/,+$//;'     \
                  )"

    extra_config+=("--enable-add-ons=${addons_list}")

    extra_config+=("${addons_config}")
    extra_config+=("$(do_libc_min_kernel_config)")

    # Pre-seed the configparms file with values from the config option
    printf "${CT_LIBC_GLIBC_CONFIGPARMS}\n" > configparms

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")
    CT_DoLog DEBUG "Using gcc for target: '${cross_cc}'"
    CT_DoLog DEBUG "Extra config passed : '${extra_config[*]}'"

    libc_cv_ppc_machine=yes                                     \
    libc_cv_mlong_double_128=yes                                \
    libc_cv_mlong_double_128ibm=yes                             \
    CC=${cross_cc}                                              \
    CT_DoExecLog CFG                                            \
    "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/configure"          \
        --build="${CT_BUILD}"                                   \
        --host="${CT_TARGET}"                                   \
        --prefix=/usr                                           \
        --with-headers="${CT_HEADERS_DIR}"                      \
        --without-cvs                                           \
        --disable-sanity-checks                                 \
        --enable-hacker-mode                                    \
        "${extra_config[@]}"                                    \
        --without-nptl

    CT_DoLog EXTRA "Installing C library headers"

    # Note: BOOTSTRAP_GCC (see above)
    libc_cv_ppc_machine=yes                         \
    CT_DoExecLog ALL                                \
    make cross-compiling=yes                        \
         install_root=${CT_SYSROOT_DIR}             \
         CFLAGS="-O2 -DBOOTSTRAP_GCC"               \
         ${LIBC_SYSROOT_ARG}                        \
         OBJDUMP_FOR_HOST="${CT_TARGET}-objdump"    \
         PARALLELMFLAGS="${PARALLELMFLAGS}"         \
         install-headers

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
    [ "${CT_ARCH}" != "arm" ] && CT_DoExecLog ALL cp -v misc/syscall-list.h "${CT_HEADERS_DIR}/bits/syscall.h" || true

    # Those headers are to be manually copied so gcc can build properly
    pthread_h="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/${CT_THREADS}/sysdeps/pthread/pthread.h"
    pthreadtypes_h=
    case "${CT_THREADS}" in
        nptl)
            # NOTE: for some archs, the pathes are different, but they are not
            # supported by crosstool-NG right now. See original crosstool when they are.
            pthread_h="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/${CT_THREADS}/sysdeps/pthread/pthread.h"
            pthreadtypes_h="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/nptl/sysdeps/unix/sysv/linux/${arch4hdrs}/bits/pthreadtypes.h"
            if [ ! -f "${pthreadtypes_h}" ]; then
                pthreadtypes_h="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/ports/sysdeps/unix/sysv/linux/${arch4hdrs}/nptl/bits/pthreadtypes.h"
            fi
            ;;
        linuxthreads)
            pthreadtypes_h="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/linuxthreads/sysdeps/pthread/bits/pthreadtypes.h"
            ;;
        *)
            pthread_h=
            pthreadtypes_h=
            ;;
    esac
    if [ -n "${pthread_h}" ]; then
        CT_DoExecLog ALL cp -v "${pthread_h}" "${CT_HEADERS_DIR}/pthread.h"
    fi
    if [ -n "${pthreadtypes_h}" ]; then
        CT_DoExecLog ALL cp -v "${pthreadtypes_h}" "${CT_HEADERS_DIR}/bits/pthreadtypes.h"
    fi

    CT_EndStep
}

# Build and install start files
do_libc_start_files() {
    local -a extra_config

    # Needed only in the NPTL case. Otherwise, return.
    [ "${CT_THREADS}" = "nptl" ] || return 0

    CT_DoStep INFO "Installing C library start files"

    mkdir -p "${CT_BUILD_DIR}/build-libc-startfiles"
    cd "${CT_BUILD_DIR}/build-libc-startfiles"

    CT_DoLog EXTRA "Configuring C library"

    # Add some default glibc config options if not given by user.
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
        *-tls*) ;;
        *) extra_config+=("--with-tls")
    esac
    case "${CT_SHARED_LIBS}" in
        y) extra_config+=("--enable-shared");;
        *) extra_config+=("--disable-shared");;
    esac
    case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
        y,) extra_config+=("--with-fp");;
        ,y) extra_config+=("--without-fp");;
    esac
    # Obviously, we want threads, as we come here only for NPTL
    extra_config+=("--with-__thread")

    addons_config="--enable-add-ons=$(do_libc_add_ons_list ,)"
    extra_config+=("${addons_config}")

    extra_config+=("$(do_libc_min_kernel_config)")

    # Add some default CC args
    glibc_version="$( grep -E '\<VERSION\>' "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/version.h"  \
                      |cut -d '"' -f 2
                    )"
    glibc_version_major=$(echo ${glibc_version} |sed -r -e 's/^([[:digit:]]+).*/\1/')
    glibc_version_minor=$(echo ${glibc_version} |sed -r -e 's/^[[:digit:]]+[\.-_]([[:digit:]]+).*/\1/')
    if [    ${glibc_version_major} -eq 2 -a ${glibc_version_minor} -ge 6    \
         -o ${glibc_version_major} -gt 2                                    ]; then
        # Don't use -pipe: configure chokes on it for glibc >= 2.6.
        CT_Test 'Removing "-pipe" for use with glibc>=2.6' "${CT_USE_PIPES}" = "y"
        extra_cc_args="${CT_CFLAGS_FOR_HOST/-pipe}"
    else
        extra_cc_args="${CT_CFLAGS_FOR_HOST}"
    fi
    extra_cc_args="${extra_cc_args} ${CT_ARCH_ENDIAN_OPT}"

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")
    CT_DoLog DEBUG "Using gcc for target    : '${cross_cc}'"
    CT_DoLog DEBUG "Configuring with addons : '$(do_libc_add_ons_list ,)'"
    CT_DoLog DEBUG "Extra config args passed: '${extra_config[*]}'"
    CT_DoLog DEBUG "Extra CC args passed    : '${extra_cc_args}'"

    # Pre-seed the configparms file with values from the config option
    printf "${CT_LIBC_GLIBC_CONFIGPARMS}\n" > configparms

    echo "libc_cv_forced_unwind=yes" > config.cache
    echo "libc_cv_c_cleanup=yes" >> config.cache

    # Please see the comment for the configure step in do_libc().

    BUILD_CC="${CT_BUILD}-gcc"                                      \
    CFLAGS="${CT_TARGET_CFLAGS} ${CT_LIBC_GLIBC_EXTRA_CFLAGS} -O2"  \
    CC="${cross_cc} ${CT_LIBC_EXTRA_CC_ARGS} ${extra_cc_args}"      \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    CT_DoExecLog CFG                                                \
    "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/configure"              \
        --prefix=/usr                                               \
        --build="${CT_BUILD}"                                       \
        --host=${CT_TARGET}                                         \
        --without-cvs                                               \
        --disable-profile                                           \
        --disable-debug                                             \
        --without-gd                                                \
        --with-headers="${CT_HEADERS_DIR}"                          \
        --cache-file=config.cache                                   \
        "${extra_config[@]}"                                        \
        ${CT_LIBC_GLIBC_EXTRA_CONFIG}

    #TODO: should check whether slibdir has been set in configparms to */lib64
    #      and copy the startfiles into the appropriate libdir.
    CT_DoLog EXTRA "Building C library start files"
    CT_DoExecLog ALL make OBJDUMP_FOR_HOST="${CT_TARGET}-objdump"   \
                          PARALLELMFLAGS="${PARALLELMFLAGS}"        \
                          csu/subdir_lib

    CT_DoLog EXTRA "Installing C library start files"
    if [ "${CT_USE_SYSROOT}" = "y" ]; then
        CT_DoExecLog ALL cp -fpv csu/crt[1in].o "${CT_SYSROOT_DIR}/usr/lib/"
    else
        CT_DoExecLog ALL cp -fpv csu/crt[1in].o "${CT_SYSROOT_DIR}/lib/"
    fi

    CT_EndStep
}

# This function builds and install the full glibc
do_libc() {
    local -a extra_config

    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    # Add some default glibc config options if not given by user.
    # We don't need to be conditional on wether the user did set different
    # values, as they CT_LIBC_GLIBC_EXTRA_CONFIG is passed after extra_config

    case "${CT_THREADS}" in
        nptl)           extra_config+=("--with-__thread" "--with-tls");;
        linuxthreads)   extra_config+=("--with-__thread" "--without-tls" "--without-nptl");;
        none)           extra_config+=("--without-__thread" "--without-nptl")
                        case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
                            *-tls*) ;;
                            *) extra_config+=("--without-tls");;
                        esac
                        ;;
    esac

    case "${CT_SHARED_LIBS}" in
        y) extra_config+=("--enable-shared");;
        *) extra_config+=("--disable-shared");;
    esac

    case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
        y,) extra_config+=("--with-fp");;
        ,y) extra_config+=("--without-fp");;
    esac

    if [ "${CT_LIBC_DISABLE_VERSIONING}" = "y" ]; then
        extra_config+=("--disable-versioning")
    fi

    if [ "${CT_LIBC_OLDEST_ABI}" != "" ]; then
        extra_config+=("--enable-oldest-abi=${CT_LIBC_OLDEST_ABI}")
    fi

    case "$(do_libc_add_ons_list ,)" in
        "") ;;
        *)  extra_config+=("--enable-add-ons=$(do_libc_add_ons_list ,)");;
    esac

    extra_config+=("$(do_libc_min_kernel_config)")

    # Add some default CC args
    glibc_version="$( grep -E '\<VERSION\>' "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/version.h"  \
                      |cut -d '"' -f 2
                    )"
    glibc_version_major=$(echo ${glibc_version} |sed -r -e 's/^([[:digit:]]+).*/\1/')
    glibc_version_minor=$(echo ${glibc_version} |sed -r -e 's/^[[:digit:]]+[\.-_]([[:digit:]]+).*/\1/')
    if [    ${glibc_version_major} -eq 2 -a ${glibc_version_minor} -ge 6    \
         -o ${glibc_version_major} -gt 2                                    ]; then
        # Don't use -pipe: configure chokes on it for glibc >= 2.6.
        CT_Test 'Removing "-pipe" for use with glibc>=2.6' "${CT_USE_PIPES}" = "y"
        extra_cc_args="${CT_CFLAGS_FOR_HOST/-pipe}"
    else
        extra_cc_args="${CT_CFLAGS_FOR_HOST}"
    fi
    extra_cc_args="${extra_cc_args} ${CT_ARCH_ENDIAN_OPT}"

    cross_cc=$(CT_Which "${CT_TARGET}-gcc")
    CT_DoLog DEBUG "Using gcc for target    : '${cross_cc}'"
    CT_DoLog DEBUG "Configuring with addons : '$(do_libc_add_ons_list ,)'"
    CT_DoLog DEBUG "Extra config args passed: '${extra_config}'"
    CT_DoLog DEBUG "Extra CC args passed    : '${extra_cc_args}'"

    # Pre-seed the configparms file with values from the config option
    printf "${CT_LIBC_GLIBC_CONFIGPARMS}\n" > configparms

    # For glibc 2.3.4 and later we need to set some autoconf cache
    # variables, because nptl/sysdeps/pthread/configure.in does not
    # work when cross-compiling.
    if [ "${CT_THREADS}" = "nptl" ]; then
        echo libc_cv_forced_unwind=yes
        echo libc_cv_c_cleanup=yes
    fi >config.cache

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
    # or even after they get installed... glibc is such a sucker...
    echo "ac_cv_path_BASH_SHELL=/bin/bash" >>config.cache

    # Configure with --prefix the way we want it on the target...
    # There are a whole lot of settings here.  You'll probably want
    # to read up on what they all mean, and customize a bit, possibly by setting GLIBC_EXTRA_CONFIG
    # Compare these options with the ones used when installing the glibc headers above - they're different.
    # Adding "--without-gd" option to avoid error "memusagestat.c:36:16: gd.h: No such file or directory" 
    # See also http://sources.redhat.com/ml/libc-alpha/2000-07/msg00024.html. 
    # Set BUILD_CC, or you won't be able to build datafiles
    # Set --build, else glibc-2.3.2 will think you're not cross-compiling, and try to run the test programs

    # OK. I'm fed up with those folks telling me what I should do.
    # I don't configure nptl? Well, maybe that's purposedly because
    # I don't want nptl! --disable-sanity-checks will shut up those
    # silly messages. GNU folks again, he?

    BUILD_CC="${CT_BUILD}-gcc"                                      \
    CFLAGS="${CT_TARGET_CFLAGS} ${CT_LIBC_GLIBC_EXTRA_CFLAGS} -O2"  \
    CC="${CT_TARGET}-gcc ${CT_LIBC_EXTRA_CC_ARGS} ${extra_cc_args}" \
    AR=${CT_TARGET}-ar                                              \
    RANLIB=${CT_TARGET}-ranlib                                      \
    CT_DoExecLog CFG                                                \
    "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}/configure"              \
        --prefix=/usr                                               \
        --build=${CT_BUILD}                                         \
        --host=${CT_TARGET}                                         \
        --without-cvs                                               \
        --disable-profile                                           \
        --disable-debug                                             \
        --without-gd                                                \
        --disable-sanity-checks                                     \
        --cache-file=config.cache                                   \
        --with-headers="${CT_HEADERS_DIR}"                          \
        "${extra_config[@]}"                                        \
        ${CT_LIBC_GLIBC_EXTRA_CONFIG}

    # glibc initial build hacks
    # http://sourceware.org/ml/crossgcc/2008-10/msg00068.html
    case "${CT_ARCH},${CT_ARCH_CPU}" in
	powerpc,8??)
	    CT_DoLog DEBUG "Activating support for memset on broken ppc-8xx (CPU15 erratum)"
	    GLIBC_INITIAL_BUILD_ASFLAGS="-DBROKEN_PPC_8xx_CPU15";;
    esac

    # If this fails with an error like this:
    # ...  linux/autoconf.h: No such file or directory 
    # then you need to set the KERNELCONFIG variable to point to a .config file for this arch.
    # The following architectures are known to need kernel .config: alpha, arm, ia64, s390, sh, sparc
    # Note: LD and RANLIB needed by glibc-2.1.3's c_stub directory, at least on macosx
    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make LD=${CT_TARGET}-ld                        \
                          RANLIB=${CT_TARGET}-ranlib                \
                          OBJDUMP_FOR_HOST="${CT_TARGET}-objdump"   \
                          ASFLAGS="${GLIBC_INITIAL_BUILD_ASFLAGS}"  \
                          PARALLELMFLAGS="${PARALLELMFLAGS}"        \
                          all

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make install_root="${CT_SYSROOT_DIR}"          \
                          ${LIBC_SYSROOT_ARG}                       \
                          OBJDUMP_FOR_HOST="${CT_TARGET}-objdump"   \
                          PARALLELMFLAGS="${PARALLELMFLAGS}"        \
                          install

    # This doesn't seem to work when building a crosscompiler,
    # as it tries to execute localedef using the just-built ld.so!?
    #CT_DoLog EXTRA "Installing locales"
    #make localedata/install-locales install_root=${SYSROOT} 2>&1 |CT_DoLog ALL

    # Fix problems in linker scripts.
    #
    # Remove lines containing BUG per http://sources.redhat.com/ml/bug-glibc/2003-05/msg00055.html,
    # needed to fix gcc-3.2.3/glibc-2.3.2 targeting arm
    # No need to look into the lib64/ dirs here and there, they point to the
    # corresponding lib/ directories.
    #
    # To make "strip *.so.*" not fail (ptxdist does this), rename to .so_orig rather than .so.orig
    CT_DoLog EXTRA "Fixing C library linker scripts"
    for file in libc.so libpthread.so libgcc_s.so; do
        for dir in lib usr/lib; do
            if [ -f "${CT_SYSROOT_DIR}/${dir}/${file}" -a ! -L ${CT_SYSROOT_DIR}/$lib/$file ]; then
                CT_DoExecLog ALL cp -v "${CT_SYSROOT_DIR}/${dir}/${file}" "${CT_SYSROOT_DIR}/${dir}/${file}_orig"
                CT_DoLog DEBUG "Fixing '${CT_SYS_ROOT_DIR}/${dir}/${file}'"
                CT_DoExecLog ALL sed -i -r -e '/BUG in libc.scripts.output-format.sed/d' "${CT_SYSROOT_DIR}/${dir}/${file}"
            fi
        done
    done

    CT_EndStep
}

# This function finishes the glibc install
do_libc_finish() {
    :
}

# Build up the addons list, separated with $1
do_libc_add_ons_list() {
    local sep="$1"
    local addons_list=$(echo "${CT_LIBC_ADDONS_LIST}" |sed -r -e "s/[ ,]/${sep}/g;")
    case "${CT_THREADS}" in
        none)   ;;
        *)      addons_list="${addons_list}${sep}${CT_THREADS}";;
    esac
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && addons_list="${addons_list}${sep}ports"
    # Remove duplicate, leading and trailing separators
    echo "${addons_list}" |sed -r -e "s/${sep}+/${sep}/g; s/^${sep}//; s/${sep}\$//;"
}

# Builds up the minimum supported Linux kernel version
do_libc_min_kernel_config() {
    local min_kernel_config=
    case "${CT_LIBC_GLIBC_EXTRA_CONFIG}" in
        *enable-kernel*) ;;
        *)  if [ "${CT_LIBC_GLIBC_KERNEL_VERSION_AS_HEADERS}" = "y" ]; then
                # We can't rely on the kernel version from the configuration,
                # because it might not be available if the user uses pre-installed
                # headers. On the other hand, both method will have the kernel
                # version installed in "usr/include/linux/version.h" in the sys-root.
                # Parse that instead of having two code-paths.
                version_code_file="${CT_SYSROOT_DIR}/usr/include/linux/version.h"
                if [ ! -f "${version_code_file}" -o ! -r "${version_code_file}" ]; then
                    CT_Abort "Linux version is unavailable in installed headers files"
                fi
                version_code=$(grep -E LINUX_VERSION_CODE "${version_code_file}" |cut -d ' ' -f 3)
                version=$(((version_code>>16)&0xFF))
                patchlevel=$(((version_code>>8)&0xFF))
                sublevel=$((version_code&0xFF))
                min_kernel_config="--enable-kernel=${version}.${patchlevel}.${sublevel}"
            elif [ "${CT_LIBC_GLIBC_KERNEL_VERSION_CHOSEN}" = "y" ]; then
                # Trim the fourth part of the linux version, keeping only the first three numbers
                min_kernel_config="--enable-kernel=$(echo ${CT_LIBC_GLIBC_MIN_KERNEL_VERSION} |sed -r -e 's/^([^.]+\.[^.]+\.[^.]+)(|\.[^.]+)$/\1/;')"
            fi
            ;;
    esac
    echo "${min_kernel_config}"
}
