# This file declares functions to install the uClibc C library
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# This is a constant because it does not change very often.
# We're in 2010, and are still using data from 7 years ago.
uclibc_locales_version=030818
uclibc_locale_tarball="uClibc-locale-${uclibc_locales_version}"

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
        CT_GetCustom "${uclibc_name}" "${CT_LIBC_UCLIBC_CUSTOM_VERSION}" \
            "${CT_LIBC_UCLIBC_CUSTOM_LOCATION}"
    else
        CT_GetFile "${uclibc_name}-${CT_LIBC_VERSION}" ${libc_src}
    fi
    # uClibc locales
    if [ "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y" ]; then
        CT_GetFile "${uclibc_locale_tarball}" ${libc_src}
    fi

    return 0
}

# Extract uClibc
do_libc_extract() {
    CT_Extract "${uclibc_name}-${CT_LIBC_VERSION}"
    CT_Patch "${uclibc_name}" "${CT_LIBC_VERSION}"

    # uClibc locales
    # Extracting pregen locales ourselves is kinda
    # broken, so just link it in place...
    if [    "${CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA}" = "y"           \
         -a ! -f "${CT_SRC_DIR}/.${uclibc_locale_tarball}.extracted" ]; then
        CT_Pushd "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}/extra/locale"
        CT_DoExecLog ALL ln -s "${CT_TARBALLS_DIR}/${uclibc_locale_tarball}.tgz" .
        CT_Popd
        touch "${CT_SRC_DIR}/.${uclibc_locale_tarball}.extracted"
    fi

    return 0
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

# Common backend for 1st and 2nd passes.
do_libc_backend() {
    local libc_mode
    local -a multilibs
    local multilib
    local multi_dir multi_os_dir multi_flags
    local ldso ldso_f ldso_d multilib_dir

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    case "${libc_mode}" in
        startfiles)     CT_DoStep INFO "Installing C library headers & start files";;
        final)          CT_DoStep INFO "Installing C library";;
        *)              CT_Abort "Unsupported (or unset) libc_mode='${libc_mode}'";;
    esac

    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libc-${libc_mode}"

    # See glibc.sh for the explanation of this magic.
    multilibs=( $("${CT_TARGET}-gcc" -print-multi-lib 2>/dev/null) )
    for multilib in "${multilibs[@]}"; do
        multi_flags=$( echo "${multilib#*;}" | ${sed} -r -e 's/@/ -/g;' )
        multi_dir="${multilib%%;*}"
        multi_os_dir=$( "${CT_TARGET}-gcc" -print-multi-os-directory ${multi_flags} )
        multi_root=$( "${CT_TARGET}-gcc" -print-sysroot ${multi_flags} )
        root_suffix="${multi_root#${CT_SYSROOT_DIR}}"
        CT_DoExecLog ALL mkdir -p "sysroot${root_suffix}"
        if [ -e "sysroot${root_suffix}/seen" ]; then
            CT_DoExecLog ALL rm -f "sysroot${root_suffix}/unique"
        else
            CT_DoExecLog ALL touch "sysroot${root_suffix}/seen" "sysroot${root_suffix}/unique"
        fi
    done

    for multilib in "${multilibs[@]}"; do
        multi_flags=$( echo "${multilib#*;}" | ${sed} -r -e 's/@/ -/g;' )
        multi_dir="${multilib%%;*}"
        multi_os_dir=$( "${CT_TARGET}-gcc" -print-multi-os-directory ${multi_flags} )
        multi_root=$( "${CT_TARGET}-gcc" -print-sysroot ${multi_flags} )
        root_suffix="${multi_root#${CT_SYSROOT_DIR}}"

        # Avoid multi_os_dir if it's the only directory in this sysroot.
        if [ -e "sysroot${root_suffix}/unique" ]; then
            multi_os_dir=.
        fi

        CT_DoStep INFO "Building for multilib '${multi_flags}'"
        do_libc_backend_once multi_dir="${multi_dir}"               \
                             multi_os_dir="${multi_os_dir}"         \
                             multi_flags="${multi_flags}"           \
                             multi_root="${multi_root}"             \
                             libc_mode="${libc_mode}"
        CT_EndStep
    done

    if [ "${libc_mode}" = "final" -a "${CT_SHARED_LIBS}" = "y" ]; then
        # uClibc and GCC disagree where the dynamic linker lives. uClibc always
        # places it in the MULTILIB_DIR, while gcc does that for *some* variants
        # and expects it in /lib for the other. So, create a symlink from lib
        # to the actual location, but only if that will not override the actual
        # file in /lib. Thus, need to do this after all the variants are built.
        echo "int main(void) { return 0; }" > test-ldso.c
        for multilib in "${multilibs[@]}"; do
            multi_flags=$( echo "${multilib#*;}" | ${sed} -r -e 's/@/ -/g;' )
            multi_os_dir=$( "${CT_TARGET}-gcc" -print-multi-os-directory ${multi_flags} )
            multi_root=$( "${CT_TARGET}-gcc" -print-sysroot ${multi_flags} )
            root_suffix="${multi_root#${CT_SYSROOT_DIR}}"

            # Avoid multi_os_dir if it's the only directory in this sysroot.
            if [ -e "sysroot${root_suffix}/unique" ]; then
                multi_os_dir=.
            fi

            multilib_dir="/lib/${multi_os_dir}"
            CT_SanitizeVarDir multilib_dir

            CT_DoExecLog ALL "${CT_TARGET}-gcc" -o test-ldso test-ldso.c ${multi_flags}
            ldso=$( ${CT_TARGET}-readelf -Wl test-ldso | \
                grep 'Requesting program interpreter: ' | \
                sed -e 's,.*: ,,' -e 's,\].*,,' )
            ldso_d="${ldso%/ld*.so.*}"
            ldso_f="${ldso##*/}"
            if [ -z "${ldso}" -o "${ldso_d}" = "${multilib_dir}" ]; then
                # GCC cannot produce shared executable, or the base directory
                # for ld.so is the same as the multi_os_directory
                continue
            fi

            # If there is no such file in the expected ldso dir, create a symlink to
            # multilib_dir ld.so
            if [ ! -r "${multi_root}${ldso}" ]; then
                # Convert ldso_d to "how many levels we need to go up" and remove
                # leading slash.
                ldso_d=$( echo "${ldso_d#/}" | sed 's,[^/]\+,..,g' )
                CT_DoExecLog ALL ln -sf "${ldso_d}${multilib_dir}/${ldso_f}" \
                    "${multi_root}${ldso}"
            fi
        done
    fi

    CT_Popd
    CT_EndStep
}

# Common backend for 1st and 2nd passes, once per multilib.
do_libc_backend_once() {
    local libc_mode
    local multi_dir multi_os_dir multi_root multilib_dir startfiles_dir
    local jflag=${CT_LIBC_UCLIBC_PARALLEL:+${JOBSFLAGS}}
    local -a make_args
    local build_dir
    local extra_cflags f cfg_cflags cf
    local hdr_install_subdir

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    # Simply copy files until uClibc has the ability to build out-of-tree
    CT_DoLog EXTRA "Copying sources to build dir"
    build_dir="multilib_${multi_dir//\//_}"
    CT_DoExecLog ALL cp -a "${CT_SRC_DIR}/${uclibc_name}-${CT_LIBC_VERSION}" "${build_dir}"
    CT_Pushd "${build_dir}"

    multilib_dir="lib/${multi_os_dir}"
    startfiles_dir="${multi_root}/usr/${multilib_dir}"
    CT_SanitizeVarDir multilib_dir startfiles_dir

    # Construct make arguments:
    # - uClibc uses the CROSS environment variable as a prefix to the compiler
    #   tools to use.  Since it requires core pass-1, thusly named compiler is
    #   already available.
    # - Note about CFLAGS: In uClibc, CFLAGS are generated by Rules.mak,
    #   depending  on the configuration of the library. That is, they are tailored
    #   to best fit the target. So it is useless and seems to be a bad thing to
    #   use LIBC_EXTRA_CFLAGS here.
    # - We do _not_ want to strip anything for now, in case we specifically
    #   asked for a debug toolchain, thus the STRIPTOOL= assignment.
    make_args=( CROSS_COMPILE="${CT_TARGET}-"                           \
                PREFIX="${multi_root}/"                                 \
                MULTILIB_DIR="${multilib_dir}"                          \
                LOCALE_DATA_FILENAME="${uclibc_locale_tarball}.tgz"     \
                STRIPTOOL=true                                          \
                ${CT_LIBC_UCLIBC_VERBOSITY}                             \
                )

    # Force the date of the pregen locale data, as the
    # newer ones that are referenced are not available
    CT_DoLog EXTRA "Applying configuration"

    # Use the default config if the user did not provide one.
    if [ -z "${CT_LIBC_UCLIBC_CONFIG_FILE}" ]; then
        CT_LIBC_UCLIBC_CONFIG_FILE="${CT_LIB_DIR}/contrib/uClibc-defconfigs/${uclibc_name}.config"
    fi

    manage_uClibc_config "${CT_LIBC_UCLIBC_CONFIG_FILE}" .config "${multi_flags}"
    CT_DoYes | CT_DoExecLog ALL ${make} "${make_args[@]}" oldconfig

    # Now filter the multilib flags. manage_uClibc_config did the opposite of
    # what Rules.mak in uClibc would do: by the multilib's CFLAGS, it determined
    # the applicable configuration options. We don't want to pass the same options
    # in the UCLIBC_EXTRA_CFLAGS again (on some targets, the options do not correctly
    # override each other). On the other hand, we do not want to lose the options
    # that are not reflected in the .config.
    extra_cflags="-pipe"
    { echo "include Rules.mak"; echo "show-cpu-flags:"; printf '\t@echo $(CPU_CFLAGS)\n'; } \
                > .show-cpu-cflags.mk
    cfg_cflags=$( ${make} "${make_args[@]}" \
        --no-print-directory -f .show-cpu-cflags.mk show-cpu-flags )
    CT_DoExecLog ALL rm -f .show-cpu-cflags.mk
    CT_DoLog DEBUG "CPU_CFLAGS detected by uClibc: ${cfg_cflags[@]}"
    for f in ${multi_flags}; do
        for cf in ${cfg_cflags}; do
            if [ "${f}" = "${cf}" ]; then
                f=
                break
            fi
        done
        if [ -n "${f}" ]; then
            extra_cflags+=" ${f}"
        fi
    done
    CT_DoLog DEBUG "Filtered multilib CFLAGS: ${extra_cflags}"
    make_args+=( UCLIBC_EXTRA_CFLAGS="${extra_cflags}" )

    # uClibc does not have a way to select the installation subdirectory for headers,
    # it is always $(DEVEL_PREFIX)/include. Also, we're reinstalling the headers
    # at the final stage (see the note below), we may already have the subdirectory
    # in /usr/include.
    CT_DoArchUClibcHeaderDir hdr_install_subdir "${multi_flags}"
    if [ -n "$hdr_install_subdir" ]; then
        CT_DoExecLog ALL cp -a "${multi_root}/usr/include" "${multi_root}/usr/include.saved"
    fi

    if [ "${libc_mode}" = "startfiles" ]; then
        CT_DoLog EXTRA "Building headers"
        CT_DoExecLog ALL ${make} "${make_args[@]}" headers

        # Ensure the directory for installing multilib-specific binaries exists.
        CT_DoExecLog ALL mkdir -p "${startfiles_dir}"

        CT_DoLog EXTRA "Installing headers"
        CT_DoExecLog ALL ${make} "${make_args[@]}" install_headers

        # The check might look bogus, but it is the same condition as is used
        # by GCC build script to enable/disable shared library support.
        if [ "${CT_THREADS}" = "nptl" ]; then
            CT_DoLog EXTRA "Building start files"
            CT_DoExecLog ALL ${make} ${jflag} "${make_args[@]}" \
                lib/crt1.o lib/crti.o lib/crtn.o

            # From:  http://git.openembedded.org/cgit.cgi/openembedded/commit/?id=ad5668a7ac7e0436db92e55caaf3fdf782b6ba3b
            # libm.so is needed for ppc, as libgcc is linked against libm.so
            # No problem to create it for other archs.
            CT_DoLog EXTRA "Building dummy shared libs"
            CT_DoExecLog ALL "${CT_TARGET}-gcc" -nostdlib -nostartfiles \
                -shared ${multi_flags} -x c /dev/null -o libdummy.so

            CT_DoLog EXTRA "Installing start files"
            CT_DoExecLog ALL ${install} -m 0644 lib/crt1.o lib/crti.o lib/crtn.o \
                                             "${startfiles_dir}"

            CT_DoLog EXTRA "Installing dummy shared libs"
            CT_DoExecLog ALL ${install} -m 0755 libdummy.so "${startfiles_dir}/libc.so"
            CT_DoExecLog ALL ${install} -m 0755 libdummy.so "${startfiles_dir}/libm.so"
        fi # CT_THREADS == nptl
    fi # libc_mode == startfiles

    if [ "${libc_mode}" = "final" ]; then
        CT_DoLog EXTRA "Cleaning up startfiles"
        CT_DoExecLog ALL rm -f "${startfiles_dir}/crt1.o" \
                    "${startfiles_dir}/crti.o" \
                    "${startfiles_dir}/crtn.o" \
                    "${startfiles_dir}/libc.so" \
                    "${startfiles_dir}/libm.so"

        CT_DoLog EXTRA "Building C library"
        CT_DoExecLog ALL ${make} "${make_args[@]}" pregen
        CT_DoExecLog ALL ${make} ${jflag} "${make_args[@]}" all

        # YEM-FIXME:
        # - we want to install 'runtime' files, eg. lib*.{a,so*}, crti.o and
        #   such files, except the headers as they already are installed
        # - "make install_dev" installs the headers, the crti.o... and the
        #   static libs, but not the dynamic libs
        # - "make install_runtime" installs the dynamic libs only
        # - "make install" calls install_runtime and install_dev
        # - so we're left with re-installing the headers... Sigh...
        CT_DoLog EXTRA "Installing C library"
        CT_DoExecLog ALL ${make} "${make_args[@]}" install
    fi # libc_mode == final

    # Now, if installing headers into a subdirectory, put everything in its place.
    # Remove the header subdirectory if it existed already.
    if [ -n "$hdr_install_subdir" ]; then
        CT_DoExecLog ALL mv "${multi_root}/usr/include" "${multi_root}/usr/include.new"
        CT_DoExecLog ALL mv "${multi_root}/usr/include.saved" "${multi_root}/usr/include"
        CT_DoExecLog ALL rm -rf "${multi_root}/usr/include/${hdr_install_subdir}"
        CT_DoExecLog ALL mv "${multi_root}/usr/include.new" "${multi_root}/usr/include/${hdr_install_subdir}"
    fi

    CT_Popd
}

# Initialises the .config file to sensible values
# $1: original file
# $2: modified file
manage_uClibc_config() {
    src="$1"
    dst="$2"
    flags="$3"

    # Start with fresh files
    CT_DoExecLog ALL cp "${src}" "${dst}"

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

    # IPv6 support
    if [ "${CT_LIBC_UCLIBC_IPV6}" = "y" ]; then
        CT_KconfigEnableOption "UCLIBC_HAS_IPV6" "${dst}"
    else
        CT_KconfigDisableOption "UCLIBC_HAS_IPV6" "${dst}"
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
    CT_KconfigDisableOption "UCLIBC_HAS_THREADS" "${dst}"
    CT_KconfigDisableOption "LINUXTHREADS_OLD" "${dst}"
    CT_KconfigDisableOption "LINUXTHREADS_NEW" "${dst}"
    CT_KconfigDisableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
    case "${CT_THREADS}:${CT_LIBC_UCLIBC_LNXTHRD}" in
        none:)
            ;;
        linuxthreads:old)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigEnableOption "LINUXTHREADS_OLD" "${dst}"
            ;;
        linuxthreads:new)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigEnableOption "LINUXTHREADS_NEW" "${dst}"
            ;;
        nptl:)
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS" "${dst}"
            CT_KconfigEnableOption "UCLIBC_HAS_THREADS_NATIVE" "${dst}"
            ;;
        *)
            CT_Abort "Incorrect thread settings: CT_THREADS='${CT_THREAD}' CT_LIBC_UCLIBC_LNXTHRD='${CT_LIBC_UCLIBC_LNXTHRD}'"
            ;;
    esac

    # Always build the libpthread_db
    CT_KconfigEnableOption "PTHREADS_DEBUG_SUPPORT" "${dst}"

    # Force on debug options if asked for
    CT_KconfigDisableOption "DODEBUG" "${dst}"
    CT_KconfigDisableOption "DODEBUG_PT" "${dst}"
    CT_KconfigDisableOption "DOASSERTS" "${dst}"
    CT_KconfigDisableOption "SUPPORT_LD_DEBUG" "${dst}"
    CT_KconfigDisableOption "SUPPORT_LD_DEBUG_EARLY" "${dst}"
    CT_KconfigDisableOption "UCLIBC_MALLOC_DEBUGGING" "${dst}"
    case "${CT_LIBC_UCLIBC_DEBUG_LEVEL}" in
        0)
            ;;
        1)
            CT_KconfigEnableOption "DODEBUG" "${dst}"
            ;;
        2)
            CT_KconfigEnableOption "DODEBUG" "${dst}"
            CT_KconfigEnableOption "DOASSERTS" "${dst}"
            CT_KconfigEnableOption "SUPPORT_LD_DEBUG" "${dst}"
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

    # Remove stripping: its the responsibility of the
    # firmware builder to strip or not.
    CT_KconfigDisableOption "DOSTRIP" "${dst}"

    # Now allow architecture to tweak as it wants
    CT_DoArchUClibcConfig "${dst}"
    CT_DoArchUClibcCflags "${dst}" "${flags}"
}

do_libc_post_cc() {
    :
}
