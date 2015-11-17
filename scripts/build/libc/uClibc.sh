# This file declares functions to install the uClibc C library
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# This is a constant because it does not change very often.
# We're in 2010, and are still using data from 7 years ago.
uclibc_locales_version=030818
uclibc_local_tarball="uClibc-locale-${uclibc_locales_version}"

if [ "${CT_LIBC_UCLIBC_NG}" = "y" ]; then
    uclibc_name="uClibc-ng"
    libc_src="http://downloads.uclibc-ng.org/releases/${CT_LIBC_VERSION}"
else
    uclibc_name="uClibc"
    libc_src="http://www.uclibc.org/downloads
              http://www.uclibc.org/downloads/old-releases"
fi

# Download uClibc
do_libc_get() {
    if [ "${CT_LIBC_UCLIBC_CUSTOM}" = "y" ]; then
        CT_GetCustom "${uclibc_name}" "${CT_LIBC_VERSION}" \
                     "${CT_LIBC_UCLIBC_CUSTOM_LOCATION}"
    else
        CT_GetFile "${uclibc_name}-${CT_LIBC_VERSION}" ${libc_src}
    fi
    # uClibc locales
    if [ "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y" ]; then
        CT_GetFile "${uclibc_local_tarball}" ${libc_src}
    fi

    return 0
}

# Extract uClibc
do_libc_extract() {
    # If not using custom directory location, extract and patch
    # Note: we do the inverse test we do in other components,
    # because here we still need to extract the locales, even for
    # custom location directory. Just use negate the whole test,
    # to keep it the same as for other components.
    if ! [ "${CT_LIBC_UCLIBC_CUSTOM}" = "y" \
         -a -d "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}" ]; then
        CT_Extract "${uclibc_name}-${CT_LIBC_VERSION}"
        CT_Patch "${uclibc_name}" "${CT_LIBC_VERSION}"
    fi

    # uClibc locales
    # Extracting pregen locales ourselves is kinda
    # broken, so just link it in place...
    if [    "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y"           \
         -a ! -f "${CT_SRC_DIR}/.${uclibc_local_tarball}.extracted" ]; then
        CT_Pushd "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}/extra/locale"
        CT_DoExecLog ALL ln -s "${CT_TARBALLS_DIR}/${uclibc_local_tarball}.tgz" .
        CT_Popd
        touch "${CT_SRC_DIR}/.${uclibc_local_tarball}.extracted"
    fi

    return 0
}

# Check that uClibc has been previously configured
do_libc_check_config() {
    CT_DoStep INFO "Checking C library configuration"

    # Use the default config if the user did not provide one.
    if [ -z "${CT_LIBC_UCLIBC_CONFIG_FILE}" ]; then
        CT_LIBC_UCLIBC_CONFIG_FILE="${CT_LIB_DIR}/contrib/uClibc-defconfigs/${uclibc_name}.config"
    fi

    if ${grep} -E '^KERNEL_SOURCE=' "${CT_LIBC_UCLIBC_CONFIG_FILE}" >/dev/null 2>&1; then
        CT_DoLog WARN "Your uClibc version refers to the kernel _sources_, which is bad."
        CT_DoLog WARN "I can't guarantee that our little hack will work. Please try to upgrade."
    fi

    CT_DoLog EXTRA "Manage uClibc configuration"
    manage_uClibc_config "${CT_LIBC_UCLIBC_CONFIG_FILE}" "${CT_CONFIG_DIR}/uClibc.config"

    CT_EndStep
}

# Build and install headers and start files
do_libc_start_files() {
    local cross

    CT_DoStep INFO "Installing C library headers"

    # Simply copy files until uClibc has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build dir"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}"   \
                            "${CT_BUILD_DIR}/build-libc-headers"
    cd "${CT_BUILD_DIR}/build-libc-headers"

    # Retrieve the config file
    CT_DoExecLog ALL cp "${CT_CONFIG_DIR}/uClibc.config" .config

    # uClibc uses the CROSS environment variable as a prefix to the
    # compiler tools to use.  Setting it to the empty string forces
    # use of the native build host tools, which we need at this
    # stage, as we don't have target tools yet.
    # BUT! With NPTL, we need a cross-compiler (and we have it)
    if [ "${CT_THREADS}" = "nptl" ]; then
        cross="${CT_TARGET}-"
    fi

    # Force the date of the pregen locale data, as the
    # newer ones that are referenced are not available
    CT_DoLog EXTRA "Applying configuration"
    CT_DoYes "" |CT_DoExecLog ALL                                   \
                 ${make} CROSS_COMPILE="${cross}"                   \
                 UCLIBC_EXTRA_CFLAGS="-pipe"                        \
                 PREFIX="${CT_SYSROOT_DIR}/"                        \
                 LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
                 oldconfig

    CT_DoLog EXTRA "Building headers"
    CT_DoExecLog ALL                                        \
    ${make} ${CT_LIBC_UCLIBC_VERBOSITY}                     \
         CROSS_COMPILE="${cross}"                           \
         UCLIBC_EXTRA_CFLAGS="-pipe"                        \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         headers

    CT_DoLog EXTRA "Installing headers"
    CT_DoExecLog ALL                                        \
    ${make} ${CT_LIBC_UCLIBC_VERBOSITY}                     \
         CROSS_COMPILE="${cross}"                           \
         UCLIBC_EXTRA_CFLAGS="-pipe"                        \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         install_headers

    if [ "${CT_THREADS}" = "nptl" ]; then
        CT_DoLog EXTRA "Building start files"
        CT_DoExecLog ALL                                        \
        ${make} ${CT_LIBC_UCLIBC_PARALLEL:+${JOBSFLAGS}}        \
             CROSS_COMPILE="${cross}"                           \
             UCLIBC_EXTRA_CFLAGS="-pipe"                        \
             PREFIX="${CT_SYSROOT_DIR}/"                        \
             STRIPTOOL=true                                     \
             ${CT_LIBC_UCLIBC_VERBOSITY}                        \
             LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
             lib/crt1.o lib/crti.o lib/crtn.o

        # From:  http://git.openembedded.org/cgit.cgi/openembedded/commit/?id=ad5668a7ac7e0436db92e55caaf3fdf782b6ba3b
        # libm.so is needed for ppc, as libgcc is linked against libm.so
        # No problem to create it for other archs.
        CT_DoLog EXTRA "Building dummy shared libs"
        CT_DoExecLog ALL "${cross}gcc" -nostdlib        \
                                       -nostartfiles    \
                                       -shared          \
                                       -x c /dev/null   \
                                       -o libdummy.so

        CT_DoLog EXTRA "Installing start files"
        CT_DoExecLog ALL ${install} -m 0644 lib/crt1.o lib/crti.o lib/crtn.o   \
                                         "${CT_SYSROOT_DIR}/usr/lib"

        CT_DoLog EXTRA "Installing dummy shared libs"
        CT_DoExecLog ALL ${install} -m 0755 libdummy.so "${CT_SYSROOT_DIR}/usr/lib/libc.so"
        CT_DoExecLog ALL ${install} -m 0755 libdummy.so "${CT_SYSROOT_DIR}/usr/lib/libm.so"
    fi # CT_THREADS == nptl

    CT_EndStep
}

# This function build and install the full uClibc
do_libc() {
    CT_DoStep INFO "Installing C library"

    # Simply copy files until uClibc has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build dir"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}"   \
                            "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    # Retrieve the config file
    CT_DoExecLog ALL cp "${CT_CONFIG_DIR}/uClibc.config" .config

    # uClibc uses the CROSS environment variable as a prefix to the compiler
    # tools to use.  The newly built tools should be in our path, so we need
    # only give the correct name for them.
    # Note about CFLAGS: In uClibc, CFLAGS are generated by Rules.mak,
    # depending  on the configuration of the library. That is, they are tailored
    # to best fit the target. So it is useless and seems to be a bad thing to
    # use LIBC_EXTRA_CFLAGS here.
    CT_DoLog EXTRA "Applying configuration"
    CT_DoYes "" |CT_DoExecLog CFG                                   \
                 ${make} CROSS_COMPILE=${CT_TARGET}-                \
                 UCLIBC_EXTRA_CFLAGS="-pipe"                        \
                 PREFIX="${CT_SYSROOT_DIR}/"                        \
                 LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
                 oldconfig

    # We do _not_ want to strip anything for now, in case we specifically
    # asked for a debug toolchain, thus the STRIPTOOL= assignment
    # /Old/ versions can not build in //
    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL                                        \
    ${make} -j1                                             \
         CROSS_COMPILE=${CT_TARGET}-                        \
         UCLIBC_EXTRA_CFLAGS="-pipe"                        \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         STRIPTOOL=true                                     \
         ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         pregen
    CT_DoExecLog ALL                                        \
    ${make} ${CT_LIBC_UCLIBC_PARALLEL:+${JOBSFLAGS}}        \
         CROSS_COMPILE=${CT_TARGET}-                        \
         UCLIBC_EXTRA_CFLAGS="-pipe"                        \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         STRIPTOOL=true                                     \
         ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         all

    # YEM-FIXME:
    # - we want to install 'runtime' files, eg. lib*.{a,so*}, crti.o and
    #   such files, except the headers as they already are installed
    # - "make install_dev" installs the headers, the crti.o... and the
    #   static libs, but not the dynamic libs
    # - "make install_runtime" installs the dynamic libs only
    # - "make install" calls install_runtime and install_dev
    # - so we're left with re-installing the headers... Sigh...
    #
    # We do _not_ want to strip anything for now, in case we specifically
    # asked for a debug toolchain, hence the STRIPTOOL= assignment
    #
    # Note: JOBSFLAGS is not usefull for installation.
    #
    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL                                        \
    ${make} CROSS_COMPILE=${CT_TARGET}-                     \
         UCLIBC_EXTRA_CFLAGS="-pipe"                        \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         STRIPTOOL=true                                     \
         ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         install

    CT_EndStep
}

# Initialises the .config file to sensible values
# $1: original file
# $2: modified file
manage_uClibc_config() {
    src="$1"
    dst="$2"

    # Start with fresh files
    CT_DoExecLog ALL rm -f "${dst}"
    CT_DoExecLog ALL mkdir -p "$(dirname ${dst})"
    CT_DoExecLog ALL cp "${src}" "${dst}"

    # Hack our target in the config file.
    case "${CT_ARCH}:${CT_ARCH_BITNESS}" in
        x86:32)      arch=i386;;
        x86:64)      arch=x86_64;;
        sh:32)       arch="sh";;
        sh:64)       arch="sh64";;
        *)           arch="${CT_ARCH}";;
    esac
    # Also remove stripping: its the responsibility of the
    # firmware builder to strip or not.
    ${sed} -i -r -e '/^TARGET_.*/d' "${dst}"
    CT_KconfigEnableOption "TARGET_${arch}" "${dst}"
    CT_KconfigSetOption "TARGET_ARCH" "${arch}" "${dst}"
    CT_KconfigDisableOption "DOSTRIP" "${dst}"

    # Ah. We may one day need architecture-specific handler here...
    case "${arch}" in
        arm*)
            if [ "${CT_ARCH_ARM_EABI}" = "y" ]; then
                CT_KconfigDisableOption "CONFIG_ARM_OABI" "${dst}"
                CT_KconfigEnableOption "CONFIG_ARM_EABI" "${dst}"
            else
                CT_KconfigDisableOption "CONFIG_ARM_EABI" "${dst}"
                CT_KconfigEnableOption "CONFIG_ARM_OABI" "${dst}"
            fi
            ;;
        i386)
            # FIXME This doesn't cover all cases of x86_32...
            case ${CT_TARGET_ARCH} in
                i386)
                    CT_KconfigEnableOption "CONFIG_386" "${dst}"
                    ;;
                i486)
                    CT_KconfigEnableOption "CONFIG_486" "${dst}"
                    ;;
                i586)
                    CT_KconfigEnableOption "CONFIG_586" "${dst}"
                    ;;
                i686)
                    CT_KconfigEnableOption "CONFIG_686" "${dst}"
                    ;;
            esac
            ;;
        mips*)
            CT_KconfigDisableOption "CONFIG_MIPS_O32_ABI" "${dst}"
            CT_KconfigDisableOption "CONFIG_MIPS_N32_ABI" "${dst}"
            CT_KconfigDisableOption "CONFIG_MIPS_N64_ABI" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_1" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_2" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_3" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_4" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS32" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS32R2" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS64" "${dst}"
            CT_KconfigDeleteOption "CONFIG_MIPS_ISA_MIPS64R2" "${dst}"
            case "${CT_ARCH_mips_ABI}" in
                32)
                    CT_KconfigEnableOption "CONFIG_MIPS_O32_ABI" "${dst}"
                    ;;
                n32)
                    CT_KconfigEnableOption "CONFIG_MIPS_N32_ABI" "${dst}"
                    ;;
                64)
                    CT_KconfigEnableOption "CONFIG_MIPS_N64_ABI" "${dst}"
                    ;;
            esac
            ;;
        powerpc*)
            CT_KconfigDisableOption "CONFIG_E500" "${dst}"
            CT_KconfigDisableOption "CONFIG_CLASSIC" "${dst}"
            CT_KconfigDeleteOption "TARGET_SUBARCH" "${dst}"
            if [ "${CT_ARCH_powerpc_ABI}" = "spe" ]; then
                CT_KconfigEnableOption "CONFIG_E500" "${dst}"
                CT_KconfigSetOption "TARGET_SUBARCH" "e500" "${dst}"
            else
                CT_KconfigEnableOption "CONFIG_CLASSIC" "${dst}"
                CT_KconfigSetOption "TARGET_SUBARCH" "classic" "${dst}"
            fi
            ;;
        sh)
            # all we really support right now is sh4:32
            CT_KconfigEnableOption "CONFIG_SH4" "${dst}"
            ;;
    esac

    # Accomodate for old and new uClibc versions, where the
    # way to select between big/little endian has changed
    case "${CT_ARCH_ENDIAN}" in
        big)
            CT_KconfigDisableOption "ARCH_LITTLE_ENDIAN" "${dst}"
            CT_KconfigDisableOption "ARCH_WANTS_LITTLE_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_BIG_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_WANTS_BIG_ENDIAN" "${dst}"
            ;;
        little)
            CT_KconfigDisableOption "ARCH_BIG_ENDIAN" "${dst}"
            CT_KconfigDisableOption "ARCH_WANTS_BIG_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_LITTLE_ENDIAN" "${dst}"
            CT_KconfigEnableOption "ARCH_WANTS_LITTLE_ENDIAN" "${dst}"
            ;;
    esac

    # Accomodate for old and new uClibc versions, where the
    # MMU settings has different config knobs
    if [ "${CT_ARCH_USE_MMU}" = "y" ]; then
        CT_KconfigEnableOption "ARCH_USE_MMU" "${dst}"
    else
        CT_KconfigDisableOption "ARCH_USE_MMU" "${dst}"
    fi

    # Accomodate for old and new uClibc version, where the
    # way to select between hard/soft float has changed
    case "${CT_ARCH_FLOAT}" in
        hard|softfp)
            CT_KconfigEnableOption "UCLIBC_HAS_FPU" "${dst}"
            CT_KconfigEnableOption "UCLIBC_HAS_FLOATS" "${dst}"
            ;;
        soft)
            CT_KconfigDisableOption "UCLIBC_HAS_FPU" "${dst}"
            CT_KconfigEnableOption "UCLIBC_HAS_FLOATS" "${dst}"
            CT_KconfigEnableOption "DO_C99_MATH" "${dst}"
            ;;
    esac
    if [ "${CT_LIBC_UCLIBC_FENV}" = "y" ]; then
        CT_KconfigEnableOption "UCLIBC_HAS_FENV" "${dst}"
    fi

    # We always want ctor/dtor
    CT_KconfigEnableOption "UCLIBC_CTOR_DTOR" "${dst}"

    # Change paths to work with crosstool-NG
    #
    # DEVEL_PREFIX is left as '/usr/' because it is post-pended to $PREFIX,
    # which is the correct value of ${PREFIX}/${TARGET}.
    CT_KconfigSetOption "DEVEL_PREFIX" "\"/usr/\"" "${dst}"
    CT_KconfigSetOption "RUNTIME_PREFIX" "\"/\"" "${dst}"
    CT_KconfigSetOption "SHARED_LIB_LOADER_PREFIX" "\"/lib/\"" "${dst}"
    CT_KconfigSetOption "KERNEL_HEADERS" "\"${CT_HEADERS_DIR}\"" "${dst}"

    # Locales support
    # Note that the two PREGEN_LOCALE and the XLOCALE lines may be missing
    # entirely if LOCALE is not set.  If LOCALE was already set, we'll
    # assume the user has already made all the appropriate generation
    # arrangements.  Note that having the uClibc Makefile download the
    # pregenerated locales is not compatible with crosstool; besides,
    # crosstool downloads them as part of getandpatch.sh.
    CT_KconfigDeleteOption "UCLIBC_DOWNLOAD_PREGENERATED_LOCALE" "${dst}"
    case "${CT_LIBC_UCLIBC_LOCALES}:${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" in
        :*)
            ;;
        y:)
            CT_KconfigEnableOption "UCLIBC_HAS_LOCALE" "${dst}"
            CT_KconfigDeleteOption "UCLIBC_PREGENERATED_LOCALE_DATA" "${dst}"
            CT_KconfigDeleteOption "UCLIBC_DOWNLOAD_PREGENERATED_LOCALE_DATA" \
                "${dst}"
            CT_KconfigDeleteOption "UCLIBC_HAS_XLOCALE" "${dst}"
            ;;
        y:y)
            CT_KconfigEnableOption "UCLIBC_HAS_LOCALE" "${dst}"
            CT_KconfigEnableOption "UCLIBC_PREGENERATED_LOCALE_DATA" "${dst}"
            CT_KconfigDeleteOption "UCLIBC_DOWNLOAD_PREGENERATED_LOCALE_DATA" \
                "${dst}"
            CT_KconfigDeleteOption "UCLIBC_HAS_XLOCALE" "${dst}"
            ;;
    esac

    # WCHAR support
    if [ "${CT_LIBC_UCLIBC_WCHAR}" = "y" ]; then
        CT_KconfigEnableOption "UCLIBC_HAS_WCHAR" "${dst}"
    else
        CT_KconfigDisableOption "UCLIBC_HAS_WCHAR" "${dst}"
    fi

    # Force on options needed for C++ if we'll be making a C++ compiler.
    # I'm not sure locales are a requirement for doing C++... Are they?
    if [ "${CT_CC_LANG_CXX}" = "y" ]; then
        CT_KconfigEnableOption "DO_C99_MATH" "${dst}"
        CT_KconfigEnableOption "UCLIBC_HAS_GNU_GETOPT" "${dst}"
    fi

    # Stack Smash Protection (SSP)
    if [ "${CT_CC_GCC_LIBSSP}" = "y" ]; then
        CT_KconfigEnableOption "UCLIBC_HAS_SSP" "${dst}"
        CT_KconfigEnableOption "UCLIBC_BUILD_SSP" "${dst}"
    else
        CT_KconfigDisableOption "UCLIBC_HAS_SSP" "${dst}"
        CT_KconfigDisableOption "UCLIBC_BUILD_SSP" "${dst}"
    fi

    # Push the threading model
    case "${CT_THREADS}:${CT_LIBC_UCLIBC_LNXTHRD}" in
        none:)
            CT_KconfigDisableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_OLD" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_NEW" "${dst}"
            CT_KconfigDisableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
            ;;
        linuxthreads:old)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigEnableOption "LINUXTHREADS_OLD" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_NEW" "${dst}"
            CT_KconfigDisableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
            ;;
        linuxthreads:new)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_OLD" "${dst}"
            CT_KconfigEnableOption "LINUXTHREADS_NEW" "${dst}"
            CT_KconfigDisableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
            ;;
        nptl:)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_OLD" "${dst}"
            CT_KconfigDisableOption "LINUXTHREADS_NEW" "${dst}"
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
            ;;
        *)
            CT_Abort "Incorrect thread settings: CT_THREADS='${CT_THREAD}' CT_LIBC_UCLIBC_LNXTHRD='${CT_LIBC_UCLIBC_LNXTHRD}'"
            ;;
    esac

    # Always build the libpthread_db
    CT_KconfigEnableOption "PTHREADS_DEBUG_SUPPORT" "${dst}"

    # Force on debug options if asked for
    case "${CT_LIBC_UCLIBC_DEBUG_LEVEL}" in
        0)
            CT_KconfigDisableOption "DODEBUG" "${dst}"
            CT_KconfigDisableOption "DODEBUG_PT" "${dst}"
            CT_KconfigDisableOption "DOASSERTS" "${dst}"
            CT_KconfigDisableOption "SUPPORT_LD_DEBUG" "${dst}"
            CT_KconfigDisableOption "SUPPORT_LD_DEBUG_EARLY" "${dst}"
            CT_KconfigDisableOption "UCLIBC_MALLOC_DEBUGGING" "${dst}"
            ;;
        1)
            CT_KconfigEnableOption "DODEBUG" "${dst}"
            CT_KconfigDisableOption "DODEBUG_PT" "${dst}"
            CT_KconfigDisableOption "DOASSERTS" "${dst}"
            CT_KconfigDisableOption "SUPPORT_LD_DEBUG" "${dst}"
            CT_KconfigDisableOption "SUPPORT_LD_DEBUG_EARLY" "${dst}"
            CT_KconfigDisableOption "UCLIBC_MALLOC_DEBUGGING" "${dst}"
            ;;
        2)
            CT_KconfigEnableOption "DODEBUG" "${dst}"
            CT_KconfigDisableOption "DODEBUG_PT" "${dst}"
            CT_KconfigEnableOption "DOASSERTS" "${dst}"
            CT_KconfigEnableOption "SUPPORT_LD_DEBUG" "${dst}"
            CT_KconfigDisableOption "SUPPORT_LD_DEBUG_EARLY" "${dst}"
            CT_KconfigEnableOption "UCLIBC_MALLOC_DEBUGGING" "${dst}"
            ;;
        3)
            CT_KconfigEnableOption "DODEBUG" "${dst}"
            CT_KconfigEnableOption "DODEBUG_PT" "${dst}"
            CT_KconfigEnableOption "DOASSERTS" "${dst}"
            CT_KconfigEnableOption "SUPPORT_LD_DEBUG" "${dst}"
            CT_KconfigEnableOption "SUPPORT_LD_DEBUG_EARLY" "${dst}"
            CT_KconfigEnableOption "UCLIBC_MALLOC_DEBUGGING" "${dst}"
            ;;
    esac
}

do_libc_post_cc() {
    :
}
