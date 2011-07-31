# This file declares functions to install the uClibc C library
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# This is a constant because it does not change very often.
# We're in 2010, and are still using data from 7 years ago.
uclibc_locales_version=030818
uclibc_local_tarball="uClibc-locale-${uclibc_locales_version}"

# Download uClibc
do_libc_get() {
    libc_src="http://www.uclibc.org/downloads
              http://www.uclibc.org/downloads/snapshots
              http://www.uclibc.org/downloads/old-releases"
    # For uClibc, we have almost every thing: releases, and snapshots
    # for the last month or so. We'll have to deal with svn revisions
    # later...
    CT_GetFile "uClibc-${CT_LIBC_VERSION}" ${libc_src}
    # uClibc locales
    if [ "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y" ]; then
        CT_GetFile "${uclibc_local_tarball}" ${libc_src}
    fi

    return 0
}

# Extract uClibc
do_libc_extract() {
    CT_Extract "uClibc-${CT_LIBC_VERSION}"
    # Don't patch snapshots
    if [    -z "${CT_LIBC_UCLIBC_V_snapshot}"      \
         -a -z "${CT_LIBC_UCLIBC_V_specific_date}" \
       ]; then
        CT_Patch "uClibc" "${CT_LIBC_VERSION}"
    fi

    # uClibc locales
    # Extracting pregen locales ourselves is kinda
    # broken, so just link it in place...
    if [    "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y"           \
         -a ! -f "${CT_SRC_DIR}/.${uclibc_local_tarball}.extracted" ]; then
        CT_Pushd "${CT_SRC_DIR}/uClibc-${CT_LIBC_VERSION}/extra/locale"
        CT_DoExecLog ALL ln -s "${CT_TARBALLS_DIR}/${uclibc_local_tarball}.tgz" .
        CT_Popd
        touch "${CT_SRC_DIR}/.${uclibc_local_tarball}.extracted"
    fi

    return 0
}

# Check that uClibc has been previously configured
do_libc_check_config() {
    CT_DoStep INFO "Checking C library configuration"

    CT_TestOrAbort "You did not provide a uClibc config file!" -n "${CT_LIBC_UCLIBC_CONFIG_FILE}" -a -f "${CT_LIBC_UCLIBC_CONFIG_FILE}"

    if grep -E '^KERNEL_SOURCE=' "${CT_LIBC_UCLIBC_CONFIG_FILE}" >/dev/null 2>&1; then
        CT_DoLog WARN "Your uClibc version refers to the kernel _sources_, which is bad."
        CT_DoLog WARN "I can't guarantee that our little hack will work. Please try to upgrade."
    fi

    CT_DoLog EXTRA "Munging uClibc configuration"
    mungeuClibcConfig "${CT_LIBC_UCLIBC_CONFIG_FILE}" "${CT_CONFIG_DIR}/uClibc.config"

    CT_EndStep
}

# Build and install headers and start files
do_libc_start_files() {
    local install_rule
    local cross

    CT_DoStep INFO "Installing C library headers"

    # Simply copy files until uClibc has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build dir"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/uClibc-${CT_LIBC_VERSION}"   \
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
                 make CROSS="${cross}"                              \
                 PREFIX="${CT_SYSROOT_DIR}/"                        \
                 LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
                 oldconfig

    CT_DoLog EXTRA "Building headers"
    CT_DoExecLog ALL                                        \
    make ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         CROSS="${cross}"                                   \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         headers

    if [ "${CT_LIBC_UCLIBC_0_9_30_or_later}" = "y" ]; then
        install_rule=install_headers
    else
        install_rule=install_dev
    fi

    CT_DoLog EXTRA "Installing headers"
    CT_DoExecLog ALL                                        \
    make ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         CROSS="${cross}"                                   \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         ${install_rule}

    if [ "${CT_THREADS}" = "nptl" ]; then
        CT_DoLog EXTRA "Building start files"
        CT_DoExecLog ALL                                        \
        make ${CT_LIBC_UCLIBC_PARALLEL:+${JOBSFLAGS}}           \
             CROSS="${cross}"                                   \
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
        CT_DoExecLog ALL install -m 0644 lib/crt1.o lib/crti.o lib/crtn.o   \
                                         "${CT_SYSROOT_DIR}/usr/lib"

        CT_DoLog EXTRA "Installing dummy shared libs"
        CT_DoExecLog ALL install -m 0755 libdummy.so "${CT_SYSROOT_DIR}/usr/lib/libc.so"
        CT_DoExecLog ALL install -m 0755 libdummy.so "${CT_SYSROOT_DIR}/usr/lib/libm.so"
    fi # CT_THREADS == nptl

    CT_EndStep
}

# This function build and install the full uClibc
do_libc() {
    CT_DoStep INFO "Installing C library"

    # Simply copy files until uClibc has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build dir"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/uClibc-${CT_LIBC_VERSION}"   \
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
                 make CROSS=${CT_TARGET}-                           \
                 PREFIX="${CT_SYSROOT_DIR}/"                        \
                 LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
                 oldconfig

    # We do _not_ want to strip anything for now, in case we specifically
    # asked for a debug toolchain, thus the STRIPTOOL= assignment
    # /Old/ versions can not build in //
    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL                                        \
    make -j1                                                \
         CROSS=${CT_TARGET}-                                \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         STRIPTOOL=true                                     \
         ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         pregen
    CT_DoExecLog ALL                                        \
    make ${CT_LIBC_UCLIBC_PARALLEL:+${JOBSFLAGS}}           \
         CROSS=${CT_TARGET}-                                \
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
    make CROSS=${CT_TARGET}-                                \
         PREFIX="${CT_SYSROOT_DIR}/"                        \
         STRIPTOOL=true                                     \
         ${CT_LIBC_UCLIBC_VERBOSITY}                        \
         LOCALE_DATA_FILENAME="${uclibc_local_tarball}.tgz" \
         install

    CT_EndStep
}

# This function is used to install those components needing the final C compiler
do_libc_finish() {
    :
}

# Initialises the .config file to sensible values
# $1: original file
# $2: munged file
mungeuClibcConfig() {
    src_config_file="$1"
    dst_config_file="$2"
    munge_file="${CT_BUILD_DIR}/munge-uClibc-config.sed"

    # Start with a fresh file
    rm -f "${munge_file}"
    touch "${munge_file}"

    # Do it all in a sub-shell, it's easier to redirect output
    (

    # Hack our target in the config file.
    case "${CT_ARCH}:${CT_ARCH_BITNESS}" in
        x86:32)      arch=i386;;
        x86:64)      arch=x86_64;;
        sh:32)       arch="sh";;
        sh:64)       arch="sh64";;
        blackfin:32) arch="bfin";;
        *)           arch="${CT_ARCH}";;
    esac
    # Also remove stripping: its the responsibility of the
    # firmware builder to strip or not.
    cat <<-ENDSED
		s/^(TARGET_.*)=y$/# \\1 is not set/
		s/^# TARGET_${arch} is not set/TARGET_${arch}=y/
		s/^TARGET_ARCH=".*"/TARGET_ARCH="${arch}"/
		s/.*(DOSTRIP).*/# \\1 is not set/
		ENDSED

    # Ah. We may one day need architecture-specific handler here...
    case "${CT_ARCH}" in
        arm)
            # Hack the ARM {E,O}ABI into the config file
            if [ "${CT_ARCH_ARM_EABI}" = "y" ]; then
                cat <<-ENDSED
					s/.*(CONFIG_ARM_OABI).*/# \\1 is not set/
					s/.*(CONFIG_ARM_EABI).*/\\1=y/
					ENDSED
            else
                cat <<-ENDSED
					s/.*(CONFIG_ARM_OABI).*/\\1=y/
					s/.*(CONFIG_ARM_EABI).*/# \\1 is not set/
					ENDSED
            fi
            ;;
        mips)
            case "${CT_ARCH_mips_ABI}" in
                32)
                    cat <<-ENDSED
						s/.*(CONFIG_MIPS_O32_ABI).*/\\1=y/
						s/.*(CONFIG_MIPS_N32_ABI).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_N64_ABI).*/# \\1 is not set/
						ENDSED
                    ;;
                # For n32 and n64, also force the ISA
                # Not so sure this is pertinent, so it's
                # commented out for now. It would take a
                # (MIPS+uClibc) expert to either remove
                # or re-enable the overrides.
                n32)
                    cat <<-ENDSED
						s/.*(CONFIG_MIPS_O32_ABI).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_N32_ABI).*/\\1=y/
						s/.*(CONFIG_MIPS_N64_ABI).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_ISA_.*).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_ISA_3).*/\\1=y/
						ENDSED
                    ;;
                64)
                    cat <<-ENDSED
						s/.*(CONFIG_MIPS_O32_ABI).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_N32_ABI).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_N64_ABI).*/\\1=y/
						s/.*(CONFIG_MIPS_ISA_.*).*/# \\1 is not set/
						s/.*(CONFIG_MIPS_ISA_MIPS64).*/\\1=y/
						ENDSED
                    ;;
            esac
            ;;
    esac

    # Accomodate for old and new uClibc versions, where the
    # way to select between big/little endian has changed
    case "${CT_ARCH_BE},${CT_ARCH_LE}" in
        y,) cat <<-ENDSED
				s/.*(ARCH_LITTLE_ENDIAN).*/# \\1 is not set/
				s/.*(ARCH_BIG_ENDIAN).*/\\1=y/
				s/.*(ARCH_WANTS_LITTLE_ENDIAN).*/# \\1 is not set/
				s/.*(ARCH_WANTS_BIG_ENDIAN).*/\\1=y/
				ENDSED
        ;;
        ,y) cat <<-ENDSED
				s/.*(ARCH_LITTLE_ENDIAN).*/\\1=y/
				s/.*(ARCH_BIG_ENDIAN).*/# \\1 is not set/
				s/.*(ARCH_WANTS_LITTLE_ENDIAN).*/\\1=y/
				s/.*(ARCH_WANTS_BIG_ENDIAN).*/# \\1 is not set/
				ENDSED
        ;;
    esac

    # Accomodate for old and new uClibc versions, where the
    # MMU settings has different config knobs
    if [ "${CT_ARCH_USE_MMU}" = "y" ]; then
        cat <<-ENDSED
			s/.*(ARCH_HAS_MMU).*/\\1=y\nARCH_USE_MMU=y/
			ENDSED
    else
        cat <<-ENDSED
			s/.*(ARCH_HAS_MMU).*/# \\1 is not set/
			/.*(ARCH_USE_MMU).*/d
			ENDSED
    fi

    # Accomodate for old and new uClibc version, where the
    # way to select between hard/soft float has changed
    case "${CT_ARCH_FLOAT_HW},${CT_ARCH_FLOAT_SW}" in
        y,) cat <<-ENDSED
				s/^[^_]*(HAS_FPU).*/\\1=y/
				s/.*(UCLIBC_HAS_FPU).*/\\1=y/
				ENDSED
            ;;
        ,y) cat <<-ENDSED
				s/^[^_]*(HAS_FPU).*/\\# \\1 is not set/
				s/.*(UCLIBC_HAS_FPU).*/# \\1 is not set/
				ENDSED
            ;;
    esac

    # Change paths to work with crosstool-NG
    # From http://www.uclibc.org/cgi-bin/viewcvs.cgi?rev=16846&view=rev
    #  " we just want the kernel headers, not the whole kernel source ...
    #  " so people may need to update their paths slightly
    quoted_kernel_source=$(echo "${CT_HEADERS_DIR}" | sed -r -e 's,/include/?$,,; s,/,\\/,g;')
    quoted_headers_dir=$(echo "${CT_HEADERS_DIR}" | sed -r -e 's,/,\\/,g;')
    # CROSS_COMPILER_PREFIX is left as is, as the CROSS parameter is forced on the command line
    # DEVEL_PREFIX is left as '/usr/' because it is post-pended to $PREFIX, wich is the correct value of ${PREFIX}/${TARGET}
    # Some (old) versions of uClibc use KERNEL_SOURCE (which is _wrong_), and
    # newer versions use KERNEL_HEADERS (which is right).
    cat <<-ENDSED
		s/^DEVEL_PREFIX=".*"/DEVEL_PREFIX="\\/usr\\/"/
		s/^RUNTIME_PREFIX=".*"/RUNTIME_PREFIX="\\/"/
		s/^SHARED_LIB_LOADER_PREFIX=.*/SHARED_LIB_LOADER_PREFIX="\\/lib\\/"/
		s/^KERNEL_SOURCE=".*"/KERNEL_SOURCE="${quoted_kernel_source}"/
		s/^KERNEL_HEADERS=".*"/KERNEL_HEADERS="${quoted_headers_dir}"/
		s/^UCLIBC_DOWNLOAD_PREGENERATED_LOCALE=y/\\# UCLIBC_DOWNLOAD_PREGENERATED_LOCALE is not set/
		ENDSED

    if [ "${CT_USE_PIPES}" = "y" ]; then
        if grep UCLIBC_EXTRA_CFLAGS extra/Configs/Config.in >/dev/null 2>&1; then
            # Good, there is special provision for such things as -pipe!
            cat <<-ENDSED
				s/^(UCLIBC_EXTRA_CFLAGS=".*)"$/\\1 -pipe"/
				ENDSED
        else
            # Hack our -pipe into WARNINGS, which will be internally incorporated to
            # CFLAGS. This a dirty hack, but yet needed
            cat <<-ENDSED
				s/^(WARNINGS=".*)"$/\\1 -pipe"/
				ENDSED
        fi
    fi

    # Locales support
    # Note that the two PREGEN_LOCALE and the XLOCALE lines may be missing
    # entirely if LOCALE is not set.  If LOCALE was already set, we'll
    # assume the user has already made all the appropriate generation
    # arrangements.  Note that having the uClibc Makefile download the
    # pregenerated locales is not compatible with crosstool; besides,
    # crosstool downloads them as part of getandpatch.sh.
    case "${CT_LIBC_UCLIBC_LOCALES}:${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" in
        :*)
            ;;
        y:)
            cat <<-ENDSED
				s/^# UCLIBC_HAS_LOCALE is not set/UCLIBC_HAS_LOCALE=y\\
				# UCLIBC_PREGENERATED_LOCALE_DATA is not set\\
				# UCLIBC_DOWNLOAD_PREGENERATED_LOCALE_DATA is not set\\
				# UCLIBC_HAS_XLOCALE is not set/
				ENDSED
            ;;
        y:y)
            cat <<-ENDSED
				s/^# UCLIBC_HAS_LOCALE is not set/UCLIBC_HAS_LOCALE=y\\
				UCLIBC_PREGENERATED_LOCALE_DATA=y\\
				# UCLIBC_DOWNLOAD_PREGENERATED_LOCALE_DATA is not set\\
				# UCLIBC_HAS_XLOCALE is not set/
				ENDSED
            ;;
    esac

    # WCHAR support
    if [ "${CT_LIBC_UCLIBC_WCHAR}" = "y" ] ; then
        cat <<-ENDSED
			s/^.*UCLIBC_HAS_WCHAR.*/UCLIBC_HAS_WCHAR=y/
			ENDSED
    else
        cat <<-ENDSED
			s/^.*UCLIBC_HAS_WCHAR.*/UCLIBC_HAS_WCHAR=n/
			ENDSED
    fi

    # Force on options needed for C++ if we'll be making a C++ compiler.
    # I'm not sure locales are a requirement for doing C++... Are they?
    if [ "${CT_CC_LANG_CXX}" = "y" ]; then
        cat <<-ENDSED
			s/^# DO_C99_MATH is not set/DO_C99_MATH=y/
			s/^# UCLIBC_CTOR_DTOR is not set/UCLIBC_CTOR_DTOR=y/
			s/^# UCLIBC_HAS_GNU_GETOPT is not set/UCLIBC_HAS_GNU_GETOPT=y/
			ENDSED
    fi

    # Push the threading model
    # Note: we take into account all of the .28, .29, .30 and .31
    #       versions, here. Even snapshots with NPTL.
    case "${CT_THREADS}:${CT_LIBC_UCLIBC_LNXTHRD}" in
        none:)
            cat <<-ENDSED
				s/^UCLIBC_HAS_THREADS=y/# UCLIBC_HAS_THREADS is not set/
				s/^LINUXTHREADS_OLD=y/# LINUXTHREADS_OLD is not set/
				s/^LINUXTHREADS_NEW=y/# LINUXTHREADS_NEW is not set/
				s/^UCLIBC_HAS_THREADS_NATIVE=y/# UCLIBC_HAS_THREADS_NATIVE is not set/
				ENDSED
            ;;
        linuxthreads:old)
            cat <<-ENDSED
				s/^# UCLIBC_HAS_THREADS is not set/UCLIBC_HAS_THREADS=y/
				s/^# LINUXTHREADS_OLD is not set/LINUXTHREADS_OLD=y/
				s/^LINUXTHREADS_NEW=y/# LINUXTHREADS_NEW is not set/
				s/^UCLIBC_HAS_THREADS_NATIVE=y/# UCLIBC_HAS_THREADS_NATIVE is not set/
				ENDSED
            ;;
        linuxthreads:new)
            cat <<-ENDSED
				s/^# UCLIBC_HAS_THREADS is not set/UCLIBC_HAS_THREADS=y/
				s/^LINUXTHREADS_OLD=y/# LINUXTHREADS_OLD is not set/
				s/^# LINUXTHREADS_NEW is not set/LINUXTHREADS_NEW=y/
				s/^UCLIBC_HAS_THREADS_NATIVE=y/# UCLIBC_HAS_THREADS_NATIVE is not set/
				ENDSED
            ;;
        nptl:)
            cat <<-ENDSED
				s/^HAS_NO_THREADS=y/# HAS_NO_THREADS is not set/
				s/^UCLIBC_HAS_THREADS=y/# UCLIBC_HAS_THREADS is not set/
				s/^LINUXTHREADS_OLD=y/# LINUXTHREADS_OLD is not set/
				s/^LINUXTHREADS_NEW=y/# LINUXTHREADS_NEW is not set/
				s/^# UCLIBC_HAS_THREADS_NATIVE is not set/UCLIBC_HAS_THREADS_NATIVE=y/
				ENDSED
            ;;
        *)
            CT_Abort "Incorrect thread settings: CT_THREADS='${CT_THREAD}' CT_LIBC_UCLIBC_LNXTHRD='${CT_LIBC_UCLIBC_LNXTHRD}'"
            ;;
    esac

    # Always build the libpthread_db
    cat <<-ENDSED
		s/^# PTHREADS_DEBUG_SUPPORT is not set.*/PTHREADS_DEBUG_SUPPORT=y/
		ENDSED

    # Force on debug options if asked for
    case "${CT_LIBC_UCLIBC_DEBUG_LEVEL}" in
      0)
        cat <<-ENDSED
			s/^DODEBUG=y/# DODEBUG is not set/
			s/^DODEBUG_PT=y/# DODEBUG_PT is not set/
			s/^DOASSERTS=y/# DOASSERTS is not set/
			s/^SUPPORT_LD_DEBUG=y/# SUPPORT_LD_DEBUG is not set/
			s/^SUPPORT_LD_DEBUG_EARLY=y/# SUPPORT_LD_DEBUG_EARLY is not set/
			s/^UCLIBC_MALLOC_DEBUGGING=y/# UCLIBC_MALLOC_DEBUGGING is not set/
			ENDSED
        ;;
      1)
        cat <<-ENDSED
			s/^# DODEBUG is not set.*/DODEBUG=y/
			s/^DODEBUG_PT=y/# DODEBUG_PT is not set/
			s/^DOASSERTS=y/# DOASSERTS is not set/
			s/^SUPPORT_LD_DEBUG=y/# SUPPORT_LD_DEBUG is not set/
			s/^SUPPORT_LD_DEBUG_EARLY=y/# SUPPORT_LD_DEBUG_EARLY is not set/
			s/^UCLIBC_MALLOC_DEBUGGING=y/# UCLIBC_MALLOC_DEBUGGING is not set/
			ENDSED
        ;;
      2)
        cat <<-ENDSED
			s/^# DODEBUG is not set.*/DODEBUG=y/
			s/^# DODEBUG_PT is not set.*/DODEBUG_PT=y/
			s/^# DOASSERTS is not set.*/DOASSERTS=y/
			s/^# SUPPORT_LD_DEBUG is not set.*/SUPPORT_LD_DEBUG=y/
			s/^# SUPPORT_LD_DEBUG_EARLY is not set.*/SUPPORT_LD_DEBUG_EARLY=y/
			s/^# UCLIBC_MALLOC_DEBUGGING is not set/UCLIBC_MALLOC_DEBUGGING=y/
			ENDSED
        ;;
    esac

    # And now, this is the end
    ) >>"${munge_file}"

    sed -r -f "${munge_file}" "${src_config_file}" >"${dst_config_file}"
}
