#!/bin/bash
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package.

# This is the main entry point to crosstool
# This will:
#   - download, extract and patch the toolchain components
#   - build and install each components in turn
#   - and eventually test the resulting toolchain

# What this file does is prepare the environment, based upon the user-choosen
# options. It also checks the existing environment for un-friendly variables,
# and builds the tools.

# Parse the common functions
# Note: some initialisation and sanitizing is done while parsing this file,
# most notably:
#  - set trap handler on errors,
#  - don't hash commands lookups,
#  - initialise logging.
. "${CT_LIB_DIR}/scripts/functions"

# Parse the configuration file
# It has some info about the logging facility, so include it early
. .config

# Overide the locale early, in case we ever translate crosstool-NG messages
[ -z "${CT_NO_OVERIDE_LC_MESSAGES}" ] && export LC_ALL=C

# Start date. Can't be done until we know the locale
CT_STAR_DATE=$(CT_DoDate +%s%N)
CT_STAR_DATE_HUMAN=$(CT_DoDate +%Y%m%d.%H%M%S)

# Yes! We can do full logging from now on!
CT_DoLog INFO "Build started ${CT_STAR_DATE_HUMAN}"

# renice oursleves
CT_DoExecLog DEBUG renice ${CT_NICE} $$

CT_DoStep DEBUG "Dumping user-supplied crosstool-NG configuration"
CT_DoExecLog DEBUG egrep '^(# |)CT_' .config
CT_EndStep

# Some sanity checks in the environment and needed tools
CT_DoLog INFO "Checking environment sanity"

CT_DoLog DEBUG "Unsetting and unexporting MAKEFLAGS"
unset MAKEFLAGS
export MAKEFLAGS

# Other environment sanity checks
CT_TestAndAbort "Don't set LD_LIBRARY_PATH. It screws up the build." -n "${LD_LIBRARY_PATH}"
CT_TestAndAbort "Don't set CFLAGS. It screws up the build." -n "${CFLAGS}"
CT_TestAndAbort "Don't set CXXFLAGS. It screws up the build." -n "${CXXFLAGS}"
CT_Test "GREP_OPTIONS screws up the build. Resetting." -n "${GREP_OPTIONS}"
export GREP_OPTIONS=

CT_DoLog INFO "Building environment variables"

# Include sub-scripts instead of calling them: that way, we do not have to
# export any variable, nor re-parse the configuration and functions files.
. "${CT_LIB_DIR}/scripts/build/arch/${CT_ARCH}.sh"
. "${CT_LIB_DIR}/scripts/build/kernel/${CT_KERNEL}.sh"
. "${CT_LIB_DIR}/scripts/build/gmp.sh"
. "${CT_LIB_DIR}/scripts/build/mpfr.sh"
. "${CT_LIB_DIR}/scripts/build/binutils.sh"
. "${CT_LIB_DIR}/scripts/build/libc/${CT_LIBC}.sh"
. "${CT_LIB_DIR}/scripts/build/cc/${CT_CC}.sh"
. "${CT_LIB_DIR}/scripts/build/tools.sh"
. "${CT_LIB_DIR}/scripts/build/debug.sh"

# Target tuple: CT_TARGET needs a little love:
CT_DoBuildTargetTuple

# Kludge: If any of the configured options needs CT_TARGET,
# then rescan the options file now:
. .config

# Second kludge: merge user-supplied target CFLAGS with architecture-provided
# target CFLAGS. Do the same for LDFLAGS in case it happens in the future.
# Put user-supplied flags at the end, so that they take precedence.
CT_TARGET_CFLAGS="${CT_ARCH_TARGET_CFLAGS} ${CT_TARGET_CFLAGS}"
CT_TARGET_LDFLAGS="${CT_ARCH_TARGET_LDFLAGS} ${CT_TARGET_LDFLAGS}"
CT_CC_CORE_EXTRA_CONFIG="${CT_ARCH_CC_CORE_EXTRA_CONFIG} ${CT_CC_CORE_EXTRA_CONFIG}"
CT_CC_EXTRA_CONFIG="${CT_ARCH_CC_EXTRA_CONFIG} ${CT_CC_EXTRA_CONFIG}"

# Where will we work?
: "${CT_WORK_DIR:=${CT_TOP_DIR}/targets}"
CT_TARBALLS_DIR="${CT_WORK_DIR}/tarballs"
CT_SRC_DIR="${CT_WORK_DIR}/src"
CT_BUILD_DIR="${CT_WORK_DIR}/${CT_TARGET}/build"
CT_DEBUG_INSTALL_DIR="${CT_INSTALL_DIR}/${CT_TARGET}/debug-root"
# Note: we'll always install the core compiler in its own directory, so as to
# not mix the two builds: core and final.
CT_CC_CORE_STATIC_PREFIX_DIR="${CT_BUILD_DIR}/${CT_CC}-core-static"
CT_CC_CORE_SHARED_PREFIX_DIR="${CT_BUILD_DIR}/${CT_CC}-core-shared"
CT_STATE_DIR="${CT_WORK_DIR}/${CT_TARGET}/state"

# We must ensure that we can restart if asked for!
if [ -n "${CT_RESTART}" -a ! -d "${CT_STATE_DIR}"  ]; then
    CT_DoLog ERROR "You asked to restart a non-restartable build"
    CT_DoLog ERROR "This happened because you didn't set CT_DEBUG_CT_SAVE_STEPS"
    CT_DoLog ERROR "in the config options for the previous build, or the state"
    CT_DoLog ERROR "directory for the previous build was deleted."
    CT_Abort "I will stop here to avoid any carnage"
fi

# If the local tarball directory does not exist, say so, and don't try to save there!
if [ ! -d "${CT_LOCAL_TARBALLS_DIR}" ]; then
    CT_DoLog WARN "Directory '${CT_LOCAL_TARBALLS_DIR}' does not exist. Will not save downloaded tarballs to local storage."
    CT_SAVE_TARBALLS=
fi

# Some more sanity checks now that we have all paths set up
case "${CT_LOCAL_TARBALLS_DIR},${CT_TARBALLS_DIR},${CT_SRC_DIR},${CT_BUILD_DIR},${CT_PREFIX_DIR},${CT_INSTALL_DIR}" in
    *" "*) CT_Abort "Don't use spaces in paths, it breaks things.";;
esac

# Check now if we can write to the destination directory:
if [ -d "${CT_INSTALL_DIR}" ]; then
    CT_TestAndAbort "Destination directory '${CT_INSTALL_DIR}' is not removable" ! -w $(dirname "${CT_INSTALL_DIR}")
fi

# Good, now grab a bit of informations on the system we're being run on,
# just in case something goes awok, and it's not our fault:
CT_SYS_USER=$(id -un)
CT_SYS_HOSTNAME=$(hostname -f 2>/dev/null || true)
# Hmmm. Some non-DHCP-enabled machines do not have an FQDN... Fall back to node name.
CT_SYS_HOSTNAME="${CT_SYS_HOSTNAME:-$(uname -n)}"
CT_SYS_KERNEL=$(uname -s)
CT_SYS_REVISION=$(uname -r)
# MacOS X lacks '-o' :
CT_SYS_OS=$(uname -o || echo "Unknown (maybe MacOS-X)")
CT_SYS_MACHINE=$(uname -m)
CT_SYS_PROCESSOR=$(uname -p)
CT_SYS_GCC=$(gcc -dumpversion)
CT_SYS_TARGET=$(CT_DoConfigGuess)
CT_TOOLCHAIN_ID="crosstool-${CT_VERSION} build ${CT_STAR_DATE_HUMAN} by ${CT_SYS_USER}@${CT_SYS_HOSTNAME}"

CT_DoLog EXTRA "Preparing working directories"

# Ah! The build directory shall be eradicated, even if we restart!
if [ -d "${CT_BUILD_DIR}" ]; then
    CT_DoForceRmdir "${CT_BUILD_DIR}"
fi

# Don't eradicate directories if we need to restart
if [ -z "${CT_RESTART}" ]; then
    # Get rid of pre-existing installed toolchain and previous build directories.
    # We need to do that _before_ we can safely log, because the log file will
    # most probably be in the toolchain directory.
    if [ "${CT_FORCE_DOWNLOAD}" = "y" -a -d "${CT_TARBALLS_DIR}" ]; then
        CT_DoForceRmdir "${CT_TARBALLS_DIR}"
    fi
    if [ "${CT_FORCE_EXTRACT}" = "y" -a -d "${CT_SRC_DIR}" ]; then
        CT_DoForceRmdir "${CT_SRC_DIR}"
    fi
    if [ -d "${CT_INSTALL_DIR}" ]; then
        CT_DoForceRmdir "${CT_INSTALL_DIR}"
    fi
    if [ -d "${CT_DEBUG_INSTALL_DIR}" ]; then
        CT_DoForceRmdir "${CT_DEBUG_INSTALL_DIR}"
    fi
    # In case we start anew, get rid of the previously saved state directory
    if [ -d "${CT_STATE_DIR}" ]; then
        CT_DoForceRmdir "${CT_STATE_DIR}"
    fi
fi

# Create the directories we'll use, even if restarting: it does no harm to
# create already existent directories, and CT_BUILD_DIR needs to be created
# anyway
CT_DoExecLog ALL mkdir -p "${CT_TARBALLS_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_SRC_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_BUILD_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_INSTALL_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_PREFIX_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_DEBUG_INSTALL_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}"
CT_DoExecLog ALL mkdir -p "${CT_STATE_DIR}"

# Kludge: CT_INSTALL_DIR and CT_PREFIX_DIR might have grown read-only if
# the previous build was successful. To be able to move the logfile there,
# switch them back to read/write
CT_DoExecLog ALL chmod -R u+w "${CT_INSTALL_DIR}" "${CT_PREFIX_DIR}"

# Redirect log to the actual log file now we can
# It's quite understandable that the log file will be installed in the install
# directory, so we must first ensure it exists and is writeable (above) before
# we can log there
exec >/dev/null
case "${CT_LOG_TO_FILE}" in
    y)  CT_LOG_FILE="${CT_PREFIX_DIR}/build.log"
        cat "${tmp_log_file}" >>"${CT_LOG_FILE}"
        rm -f "${tmp_log_file}"
        exec >>"${CT_LOG_FILE}"
        ;;
    *)  rm -f "${tmp_log_file}"
        ;;
esac

# Setting up the rest of the environment only if not restarting
if [ -z "${CT_RESTART}" ]; then
    # What's our shell?
    # Will be plain /bin/sh on most systems, except if we have /bin/ash and we
    # _explictly_ required using it
    CT_SHELL="/bin/sh"
    [ "${CT_CONFIG_SHELL_ASH}" = "y" -a -x "/bin/ash" ] && CT_SHELL="/bin/ash"

    # Arrange paths depending on wether we use sys-root or not.
    if [ "${CT_USE_SYSROOT}" = "y" ]; then
        CT_SYSROOT_DIR="${CT_PREFIX_DIR}/${CT_TARGET}/sys-root"
        CT_HEADERS_DIR="${CT_SYSROOT_DIR}/usr/include"
        BINUTILS_SYSROOT_ARG="--with-sysroot=${CT_SYSROOT_DIR}"
        CC_CORE_SYSROOT_ARG="--with-sysroot=${CT_SYSROOT_DIR}"
        CC_SYSROOT_ARG="--with-sysroot=${CT_SYSROOT_DIR}"
        LIBC_SYSROOT_ARG=""
        # glibc's prefix must be exactly /usr, else --with-sysroot'd gcc will get
        # confused when $sysroot/usr/include is not present.
        # Note: --prefix=/usr is magic!
        # See http://www.gnu.org/software/libc/FAQ.html#s-2.2
    else
        # plain old way. All libraries in prefix/target/lib
        CT_SYSROOT_DIR="${CT_PREFIX_DIR}/${CT_TARGET}"
        CT_HEADERS_DIR="${CT_SYSROOT_DIR}/include"
        # hack!  Always use --with-sysroot for binutils.
        # binutils 2.14 and later obey it, older binutils ignore it.
        # Lets you build a working 32->64 bit cross gcc
        BINUTILS_SYSROOT_ARG="--with-sysroot=${CT_SYSROOT_DIR}"
        # Use --with-headers, else final gcc will define disable_glibc while
        # building libgcc, and you'll have no profiling
        CC_CORE_SYSROOT_ARG="--without-headers"
        CC_SYSROOT_ARG="--with-headers=${CT_HEADERS_DIR}"
        LIBC_SYSROOT_ARG="prefix="
    fi

    # Prepare the 'lib' directories in sysroot, else the ../lib64 hack used by
    # 32 -> 64 bit crosscompilers won't work, and build of final gcc will fail with
    #  "ld: cannot open crti.o: No such file or directory"
    CT_DoExecLog ALL mkdir -p "${CT_SYSROOT_DIR}/lib"
    CT_DoExecLog ALL mkdir -p "${CT_SYSROOT_DIR}/usr/lib"

    # Prevent gcc from installing its libraries outside of the sys-root
    CT_DoExecLog ALL ln -sf "sys-root/lib" "${CT_PREFIX_DIR}/${CT_TARGET}/lib"

    # Now, in case we're 64 bits, just have lib64/ be a symlink to lib/
    # so as to have all libraries in the same directory (we can do that
    # because we are *not* multilib).
    if [ "${CT_ARCH_64}" = "y" ]; then
        CT_DoExecLog ALL ln -sf "lib" "${CT_SYSROOT_DIR}/lib64"
        CT_DoExecLog ALL ln -sf "lib" "${CT_SYSROOT_DIR}/usr/lib64"
        CT_DoExecLog ALL ln -sf "sys-root/lib" "${CT_PREFIX_DIR}/${CT_TARGET}/lib64"
    fi

    # Determine build system if not set by the user
    CT_Test "You did not specify the build system. That's OK, I can guess..." -z "${CT_BUILD}"
    case "${CT_BUILD}" in
        "") CT_BUILD=$("${CT_BUILD_PREFIX}gcc${CT_BUILD_SUFFIX}" -dumpmachine);;
    esac

    # Prepare mangling patterns to later modify BUILD and HOST (see below)
    case "${CT_TOOLCHAIN_TYPE}" in
        cross)
            CT_HOST="${CT_BUILD}"
            build_mangle="build_"
            host_mangle="build_"
            ;;
        *)  CT_Abort "No code for '${CT_TOOLCHAIN_TYPE}' toolchain type!"
            ;;
    esac

    # Save the real tuples to generate shell-wrappers to the real tools
    CT_REAL_BUILD="${CT_BUILD}"
    CT_REAL_HOST="${CT_HOST}"

    # Canonicalise CT_BUILD and CT_HOST
    # Not only will it give us full-qualified tuples, but it will also ensure
    # that they are valid tuples (in case of typo with user-provided tuples)
    # That's way better than trying to rewrite config.sub ourselves...
    CT_BUILD=$(CT_DoConfigSub "${CT_BUILD}")
    CT_HOST=$(CT_DoConfigSub "${CT_HOST}")

    # Modify BUILD and HOST so that gcc always generate a cross-compiler
    # even if any of the build, host or target machines are the same.
    # NOTE: we'll have to mangle the (BUILD|HOST)->TARGET x-compiler to
    #       support canadain build, later...
    CT_BUILD="${CT_BUILD/-/-${build_mangle}}"
    CT_HOST="${CT_HOST/-/-${host_mangle}}"

    # Now we have mangled our BUILD and HOST tuples, we must fake the new
    # cross-tools for those mangled tuples.
    CT_DoLog DEBUG "Making build system tools available"
    CT_DoExecLog ALL mkdir -p "${CT_PREFIX_DIR}/bin"
    for m in BUILD HOST; do
        r="CT_REAL_${m}"
        v="CT_${m}"
        p="CT_${m}_PREFIX"
        s="CT_${m}_SUFFIX"
        if [ -n "${!p}" ]; then
            t="${!p}"
        else
            t="${!r}-"
        fi

        for tool in ar as dlltool gcc g++ gcj gnatbind gnatmake ld nm objcopy objdump ranlib strip windres; do
            # First try with prefix + suffix
            # Then try with prefix only
            # Then try with suffix only, but only for BUILD, and HOST iff REAL_BUILD == REAL_HOST
            # Finally try with neither prefix nor suffix, but only for BUILD, and HOST iff REAL_BUILD == REAL_HOST
            # This is needed, because some tools have a prefix and
            # a suffix (eg. gcc), while others may have only one,
            # or even none (eg. binutils)
            where=$(CT_Which "${t}${tool}${!s}")
            [ -z "${where}" ] && where=$(CT_Which "${t}${tool}")
            if [    -z "${where}"                         \
                 -a \(    "${m}" = "BUILD"                \
                       -o "${CT_REAL_BUILD}" = "${!r}" \) ]; then
                where=$(CT_Which "${tool}${!s}")
            fi
            if [ -z "${where}"                            \
                 -a \(    "${m}" = "BUILD"                \
                       -o "${CT_REAL_BUILD}" = "${!r}" \) ]; then
                where=$(CT_Which "${tool}")
            fi

            # Not all tools are available for all platforms, but some are really,
            # bally needed
            if [ -n "${where}" ]; then
                CT_DoLog DEBUG "  '${!v}-${tool}' -> '${where}'"
                printf "#${BANG}${CT_SHELL}\nexec '${where}' \"\${@}\"\n" >"${CT_PREFIX_DIR}/bin/${!v}-${tool}"
                CT_DoExecLog ALL chmod 700 "${CT_PREFIX_DIR}/bin/${!v}-${tool}"
            else
                # We'll at least need some of them...
                case "${tool}" in
                    ar|as|gcc|ld|nm|objcopy|objdump|ranlib)
                        CT_Abort "Missing: '${t}${tool}${!s}' or '${t}${tool}' or '${tool}' : either needed!"
                        ;;
                    *)
                        # It does not deserve a WARN level.
                        CT_DoLog DEBUG "  Missing: '${t}${tool}${!s}' or '${t}${tool}' or '${tool}' : not required."
                        ;;
                esac
            fi
        done
    done

    # Carefully add paths in the order we want them:
    #  - first try in ${CT_PREFIX_DIR}/bin
    #  - then try in ${CT_CC_CORE_SHARED_PREFIX_DIR}/bin
    #  - then try in ${CT_CC_CORE_STATIC_PREFIX_DIR}/bin
    #  - fall back to searching user's PATH
    # Of course, neither cross-native nor canadian can run on BUILD,
    # so don't add those PATHs in this case...
    case "${CT_TOOLCHAIN_TYPE}" in
        cross)  export PATH="${CT_PREFIX_DIR}/bin:${CT_CC_CORE_SHARED_PREFIX_DIR}/bin:${CT_CC_CORE_STATIC_PREFIX_DIR}/bin:${PATH}";;
        *)  ;;
    esac

    # Some makeinfo versions are a pain in [put your most sensible body part here].
    # Go ahead with those, by creating a wrapper that keeps partial files, and that
    # never fails:
    CT_DoLog DEBUG "  'makeinfo' -> '$(CT_Which makeinfo)'"
    printf "#${BANG}/bin/sh\n$(CT_Which makeinfo) --force \"\${@}\"\ntrue\n" >"${CT_PREFIX_DIR}/bin/makeinfo"
    CT_DoExecLog ALL chmod 700 "${CT_PREFIX_DIR}/bin/makeinfo"

    # Help gcc
    CT_CFLAGS_FOR_HOST=
    [ "${CT_USE_PIPES}" = "y" ] && CT_CFLAGS_FOR_HOST="${CT_CFLAGS_FOR_HOST} -pipe"

    # Override the configured jobs with what's been given on the command line
    [ -n "${CT_JOBS}" ] && CT_PARALLEL_JOBS="${CT_JOBS}"

    # Set the shell to be used by ./configure scripts and by Makefiles (those
    # that support it!).
    export CONFIG_SHELL="${CT_SHELL}"

    # And help make go faster
    PARALLELMFLAGS=
    [ ${CT_PARALLEL_JOBS} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -j${CT_PARALLEL_JOBS}"
    [ ${CT_LOAD} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -l${CT_LOAD}"
    export PARALLELMFLAGS

    CT_DoLog EXTRA "Installing user-supplied crosstool-NG configuration"
    CT_DoExecLog DEBUG install -m 0755 "${CT_LIB_DIR}/scripts/toolchain-config.in" "${CT_PREFIX_DIR}/bin/${CT_TARGET}-ct-ng.config"
    bzip2 -c -9 .config >>"${CT_PREFIX_DIR}/bin/${CT_TARGET}-ct-ng.config"

    CT_DoStep EXTRA "Dumping internal crosstool-NG configuration"
    CT_DoLog EXTRA "Building a toolchain for:"
    CT_DoLog EXTRA "  build  = ${CT_REAL_BUILD}"
    CT_DoLog EXTRA "  host   = ${CT_REAL_HOST}"
    CT_DoLog EXTRA "  target = ${CT_TARGET}"
    set |egrep '^CT_.+=' |sort |CT_DoLog DEBUG
    CT_EndStep
fi

if [ -z "${CT_RESTART}" ]; then
    CT_DoStep INFO "Retrieving needed toolchain components' tarballs"
    do_kernel_get
    do_gmp_get
    do_mpfr_get
    do_binutils_get
    do_cc_get
    do_libc_get
    do_tools_get
    do_debug_get
    CT_EndStep

    if [ "${CT_ONLY_DOWNLOAD}" != "y" ]; then
        if [ "${CT_FORCE_EXTRACT}" = "y" ]; then
            CT_DoForceRmdir "${CT_SRC_DIR}"
            CT_DoExecLog ALL mkdir -p "${CT_SRC_DIR}"
        fi
        CT_DoStep INFO "Extracting and patching toolchain components"
        do_kernel_extract
        do_gmp_extract
        do_mpfr_extract
        do_binutils_extract
        do_cc_extract
        do_libc_extract
        do_tools_extract
        do_debug_extract
        CT_EndStep
    fi
fi

# Now for the job by itself. Go have a coffee!
if [ "${CT_ONLY_DOWNLOAD}" != "y" -a "${CT_ONLY_EXTRACT}" != "y" ]; then
    # Because of CT_RESTART, this becomes quite complex
    do_stop=0
    prev_step=
    [ -n "${CT_RESTART}" ] && do_it=0 || do_it=1
    # Aha! CT_STEPS comes from steps.mk!
    for step in ${CT_STEPS}; do
        if [ ${do_it} -eq 0 ]; then
            if [ "${CT_RESTART}" = "${step}" ]; then
                CT_DoLoadState "${step}"
                do_it=1
                do_stop=0
            fi
        else
            CT_DoSaveState ${step}
            if [ ${do_stop} -eq 1 ]; then
                CT_DoLog ERROR "Stopping just after step '${prev_step}', as requested."
                exit 0
            fi
        fi
        if [ ${do_it} -eq 1 ]; then
            do_${step}
            if [ "${CT_STOP}" = "${step}" ]; then
                do_stop=1
            fi
            if [ "${CT_DEBUG_PAUSE_STEPS}" = "y" ]; then
                CT_DoPause "Step '${step}' finished"
            fi
        fi
        prev_step="${step}"
    done
fi

CT_DoEnd INFO

# From now-on, it can become impossible to log any time, because
# either we're compressing the log file, or it can become RO any
# moment... Consign all ouptut to oblivion...
CT_DoLog INFO "Finishing installation (may take a few seconds)..."
exec >/dev/null 2>&1

[ "${CT_LOG_FILE_COMPRESS}" = y ] && bzip2 -9 "${CT_LOG_FILE}"
[ "${CT_INSTALL_DIR_RO}" = "y"  ] && chmod -R a-w "${CT_INSTALL_DIR}"

trap - EXIT
