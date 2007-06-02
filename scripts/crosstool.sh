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

# CT_TOP_DIR is set by the makefile. If we don't have it, something's gone horribly wrong...
if [ -z "${CT_TOP_DIR}" -o ! -d "${CT_TOP_DIR}" ]; then
    # We don't have the functions right now, because we don't have CT_TOP_DIR.
    # Do the print stuff by hand:
    echo "CT_TOP_DIR not set, or not a directory. Something's gone horribly wrong."
    echo "Please send a bug report (see README)"
    exit 1
fi

# Parse the common functions
. "${CT_TOP_DIR}/scripts/functions"

CT_STAR_DATE=`CT_DoDate +%s%N`
CT_STAR_DATE_HUMAN=`CT_DoDate +%Y%m%d.%H%M%S`

# Log policy:
#  - first of all, save stdout so we can see the live logs: fd #6
exec 6>&1
#  - then point stdout to the log file (temporary for now)
tmp_log_file="${CT_TOP_DIR}/log.$$"
exec >>"${tmp_log_file}"

# Are we configured? We'll need that later...
CT_TestOrAbort "Configuration file not found. Please create one." -f "${CT_TOP_DIR}/.config"

# Parse the configuration file
# It has some info about the logging facility, so include it early
. "${CT_TOP_DIR}/.config"

# renice oursleves
renice ${CT_NICE} $$ |CT_DoLog DEBUG

# Yes! We can do full logging from now on!
CT_DoLog INFO "Build started ${CT_STAR_DATE_HUMAN}"

CT_DoStep DEBUG "Dumping crosstool-NG configuration"
cat ${CT_TOP_DIR}/.config |egrep '^(# |)CT_' |CT_DoLog DEBUG
CT_EndStep

# Some sanity checks in the environment and needed tools
CT_DoLog INFO "Checking environment sanity"

# Enable known ordering of files in directory listings:
CT_Test "Crosstool-NG might not work as expected with LANG=\"${LANG}\"" -n "${LANG}"
case "${LC_COLLATE},${LC_ALL}" in
  # These four combinations are known to sort files in the correct order:
  fr_FR*,)  ;;
  en_US*,)  ;;
  *,fr_FR*) ;;
  *,en_US*) ;;
  # Anything else is destined to be borked if not gracefuly handled:
  *) CT_DoLog WARN "Either LC_COLLATE=\"${LC_COLLATE}\" or LC_ALL=\"${LC_ALL}\" is not supported."
     export LC_ALL=`locale -a |egrep "^(fr_FR|en_US)" |head -n 1`
     CT_TestOrAbort "Neither en_US* nor fr_FR* locales found on your system." -n "${LC_ALL}"
     CT_DoLog WARN "Forcing to known working LC_ALL=\"${LC_ALL}\"."
     ;;
esac

# Other environment sanity checks
CT_TestAndAbort "Don't set LD_LIBRARY_PATH. It screws up the build." -n "${LD_LIBRARY_PATH}"
CT_TestAndAbort "Don't set CFLAGS. It screws up the build." -n "${CFLAGS}"
CT_TestAndAbort "Don't set CXXFLAGS. It screws up the build." -n "${CXXFLAGS}"
CT_Test "GREP_OPTIONS screws up the build. Resetting." -n "${GREP_OPTIONS}"
GREP_OPTIONS=
CT_HasOrAbort awk
CT_HasOrAbort sed
CT_HasOrAbort bison
CT_HasOrAbort flex

CT_DoLog INFO "Building environment variables"

# Target triplet: CT_TARGET needs a little love:
CT_DoBuildTargetTriplet

# Kludge: If any of the configured options needs CT_TARGET,
# then rescan the options file now:
. "${CT_TOP_DIR}/.config"

# Now, build up the variables from the user-configured options.
CT_KERNEL_FILE="${CT_KERNEL}-${CT_KERNEL_VERSION}"
CT_BINUTILS_FILE="binutils-${CT_BINUTILS_VERSION}"
if [ "${CT_CC_USE_CORE}" != "y" ]; then
    CT_CC_CORE="${CT_CC}"
    CT_CC_CORE_VERSION="${CT_CC_VERSION}"
    CT_CC_CORE_EXTRA_CONFIG="${CT_CC_EXTRA_CONFIG}"
fi
CT_CC_CORE_FILE="${CT_CC_CORE}-${CT_CC_CORE_VERSION}"
CT_CC_FILE="${CT_CC}-${CT_CC_VERSION}"
CT_LIBC_FILE="${CT_LIBC}-${CT_LIBC_VERSION}"
CT_LIBFLOAT_FILE="libfloat-${CT_LIBFLOAT_VERSION}"

# Where will we work?
CT_TARBALLS_DIR="${CT_TOP_DIR}/targets/tarballs"
CT_SRC_DIR="${CT_TOP_DIR}/targets/src"
CT_BUILD_DIR="${CT_TOP_DIR}/targets/${CT_TARGET}/build"
CT_DEBUG_INSTALL_DIR="${CT_INSTALL_DIR}/${CT_TARGET}/debug-root"
# Note: we'll always install the core compiler in its own directory, so as to
# not mix the two builds: core and final. Anyway, its generic, wether we use
# a different compiler as core, or not.
CT_CC_CORE_STATIC_PREFIX_DIR="${CT_BUILD_DIR}/${CT_CC}-core-static"
CT_CC_CORE_SHARED_PREFIX_DIR="${CT_BUILD_DIR}/${CT_CC}-core-shared"
CT_STATE_DIR="${CT_TOP_DIR}/targets/${CT_TARGET}/state"

# We must ensure that we can restart if asked for!
if [ -n "${CT_RESTART}" -a ! -d "${CT_STATE_DIR}"  ]; then
    CT_DoLog ERROR "You asked to restart a non-restartable build"
    CT_DoLog ERROR "This happened because you didn't set CT_DEBUG_CT_SAVE_STEPS"
    CT_DoLog ERROR "in the config options for the previous build, or the state"
    CT_DoLog ERROR "directoy for the previous build was deleted."
    CT_Abort "I will stop here to avoid any carnage"
fi

# Make all path absolute, it so much easier!
CT_LOCAL_TARBALLS_DIR="`CT_MakeAbsolutePath \"${CT_LOCAL_TARBALLS_DIR}\"`"

# Some more sanity checks now that we have all paths set up
case "${CT_TARBALLS_DIR},${CT_SRC_DIR},${CT_BUILD_DIR},${CT_PREFIX_DIR},${CT_INSTALL_DIR}" in
    *" "*) CT_Abort "Don't use spaces in paths, it breaks things.";;
esac

# Check now if we can write to the destination directory:
if [ -d "${CT_INSTALL_DIR}" ]; then
    CT_TestAndAbort "Destination directory \"${CT_INSTALL_DIR}\" is not removable" ! -w `dirname "${CT_INSTALL_DIR}"`
fi

# Good, now grab a bit of informations on the system we're being run on,
# just in case something goes awok, and it's not our fault:
CT_SYS_USER="`id -un`"
CT_SYS_HOSTNAME=`hostname -f 2>/dev/null || true`
# Hmmm. Some non-DHCP-enabled machines do not have an FQDN... Fall back to node name.
CT_SYS_HOSTNAME="${CT_SYS_HOSTNAME:-`uname -n`}"
CT_SYS_KERNEL=`uname -s`
CT_SYS_REVISION=`uname -r`
# MacOS X lacks '-o' :
CT_SYS_OS=`uname -o || echo "Unknown (maybe MacOS-X)"`
CT_SYS_MACHINE=`uname -m`
CT_SYS_PROCESSOR=`uname -p`
CT_SYS_GCC=`gcc -dumpversion`
CT_SYS_TARGET=`${CT_TOP_DIR}/tools/config.guess`
CT_TOOLCHAIN_ID="crosstool-${CT_VERSION} build ${CT_STAR_DATE_HUMAN} by ${CT_SYS_USER}@${CT_SYS_HOSTNAME}"

CT_DoLog EXTRA "Preparing working directories"

# Ah! The build directory shall be eradicated, even if we restart!
if [ -d "${CT_BUILD_DIR}" ]; then
    mv "${CT_BUILD_DIR}" "${CT_BUILD_DIR}.$$"
    chmod -R u+w "${CT_BUILD_DIR}.$$"
    nohup rm -rf "${CT_BUILD_DIR}.$$" >/dev/null 2>&1 &
fi

# Don't eradicate directories if we need to restart
if [ -z "${CT_RESTART}" ]; then
    # Get rid of pre-existing installed toolchain and previous build directories.
    # We need to do that _before_ we can safely log, because the log file will
    # most probably be in the toolchain directory.
    if [ "${CT_FORCE_DOWNLOAD}" = "y" -a -d "${CT_TARBALLS_DIR}" ]; then
        mv "${CT_TARBALLS_DIR}" "${CT_TARBALLS_DIR}.$$"
        chmod -R u+w "${CT_TARBALLS_DIR}.$$"
        nohup rm -rf "${CT_TARBALLS_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ "${CT_FORCE_EXTRACT}" = "y" -a -d "${CT_SRC_DIR}" ]; then
        mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
        chmod -R u+w "${CT_SRC_DIR}.$$"
        nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ -d "${CT_INSTALL_DIR}" ]; then
        mv "${CT_INSTALL_DIR}" "${CT_INSTALL_DIR}.$$"
        chmod -R u+w "${CT_INSTALL_DIR}.$$"
        nohup rm -rf "${CT_INSTALL_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ -d "${CT_DEBUG_INSTALL_DIR}" ]; then
        mv "${CT_DEBUG_INSTALL_DIR}" "${CT_DEBUG_INSTALL_DIR}.$$"
        chmod -R u+w "${CT_DEBUG_INSTALL_DIR}.$$"
        nohup rm -rf "${CT_DEBUG_INSTALL_DIR}.$$" >/dev/null 2>&1 &
    fi
    # In case we start anew, get rid of the previously saved state directory
    if [ -d "${CT_STATE_DIR}" ]; then
        mv "${CT_STATE_DIR}" "${CT_STATE_DIR}.$$"
        chmod -R u+w "${CT_STATE_DIR}.$$"
        nohup rm -rf "${CT_STATE_DIR}.$$" >/dev/null 2>&1 &
    fi
fi

# Create the directories we'll use, even if restarting: it does no harm to
# create already existent directories, and CT_BUILD_DIR needs to be created
# anyway
mkdir -p "${CT_TARBALLS_DIR}"
mkdir -p "${CT_SRC_DIR}"
mkdir -p "${CT_BUILD_DIR}"
mkdir -p "${CT_INSTALL_DIR}"
mkdir -p "${CT_PREFIX_DIR}"
mkdir -p "${CT_DEBUG_INSTALL_DIR}"
mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}"
mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}"
mkdir -p "${CT_STATE_DIR}"

# Kludge: CT_INSTALL_DIR and CT_PREFIX_DIR might have grown read-only if
# the previous build was successfull. To be able to move the logfile there,
# switch them back to read/write
chmod -R u+w "${CT_INSTALL_DIR}" "${CT_PREFIX_DIR}"

# Redirect log to the actual log file now we can
# It's quite understandable that the log file will be installed in the install
# directory, so we must first ensure it exists and is writeable (above) before
# we can log there
exec >/dev/null
case "${CT_LOG_TO_FILE},${CT_LOG_FILE}" in
    ,*)   rm -f "${tmp_log_file}"
          ;;
    y,/*) mkdir -p "`dirname \"${CT_LOG_FILE}\"`"
          cat "${tmp_log_file}" >>"${CT_LOG_FILE}"
          rm -f "${tmp_log_file}"
          exec >>"${CT_LOG_FILE}"
          ;;
    y,*)  mkdir -p "`pwd`/`dirname \"${CT_LOG_FILE}\"`"
          cat "${tmp_log_file}" >>"`pwd`/${CT_LOG_FILE}"
          rm -f "${tmp_log_file}"
          exec >>"${CT_LOG_FILE}"
          ;;
esac

# Setting up the rest of the environment only is not restarting
if [ -z "${CT_RESTART}" ]; then
    # Determine build system if not set by the user
    CT_Test "You did not specify the build system. That's OK, I can guess..." -z "${CT_BUILD}"
    CT_BUILD="`${CT_TOP_DIR}/tools/config.sub \"${CT_BUILD:-\`${CT_TOP_DIR}/tools/config.guess\`}\"`"

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
    mkdir -p "${CT_SYSROOT_DIR}/lib"
    mkdir -p "${CT_SYSROOT_DIR}/usr/lib"

    # Canadian-cross are really picky on the way they are built. Tweak the values.
    CT_UNIQ_BUILD=`echo "${CT_BUILD}" |sed -r -e 's/-/-build_/'`
    if [ "${CT_CANADIAN}" = "y" ]; then
        # Arrange so that gcc never, ever think that build system == host system
        CT_CANADIAN_OPT="--build=${CT_UNIQ_BUILD}"
        # We shall have a compiler for this target!
        # Do test here...
    else
        CT_HOST="${CT_BUILD}"
        CT_CANADIAN_OPT="--build=${CT_BUILD}"
        # Add the target toolchain in the path so that we can build the C library
        # Carefully add paths in the order we want them:
        #  - first try in ${CT_PREFIX_DIR}/bin
        #  - then try in ${CT_CC_CORE_SHARED_PREFIX_DIR}/bin
        #  - then try in ${CT_CC_CORE_STATIC_PREFIX_DIR}/bin
        #  - fall back to searching user's PATH
        export PATH="${CT_PREFIX_DIR}/bin:${CT_CC_CORE_SHARED_PREFIX_DIR}/bin:${CT_CC_CORE_STATIC_PREFIX_DIR}/bin:${PATH}"
    fi

    # Modify GCC_HOST to never be equal to $BUILD or $TARGET
    # This strange operation causes gcc to always generate a cross-compiler
    # even if the build machine is the same kind as the host.
    # This is why CC has to be set when doing a canadian cross; you can't find a
    # host compiler by appending -gcc to our whacky $GCC_HOST
    # Kludge: it is reported that the above causes canadian crosses with cygwin
    # hosts to fail, so avoid it just in that one case.  It would be cleaner to
    # just move this into the non-canadian case above, but I'm afraid that might
    # cause some configure script somewhere to decide that since build==host, they
    # could run host binaries.
    # (Copied almost as-is from original crosstool):
    case "${CT_KERNEL},${CT_CANADIAN}" in
        cygwin,y) ;;
        *,y)      CT_HOST="`echo \"${CT_HOST}\" |sed -r -e 's/-/-host_/;'`";;
    esac

    # Ah! Recent versions of binutils need some of the build and/or host system
    # (read CT_BUILD and CT_HOST) tools to be accessible (ar is but an example).
    # Do that:
    CT_DoLog EXTRA "Making build system tools available"
    mkdir -p "${CT_PREFIX_DIR}/bin"
    for tool in ar as dlltool gcc g++ gnatbind gnatmake ld nm ranlib strip windres objcopy objdump; do
        if [ -n "`which ${tool}`" ]; then
            ln -sfv "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_BUILD}-${tool}"
            ln -sfv "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_UNIQ_BUILD}-${tool}"
            ln -sfv "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_HOST}-${tool}"
        fi |CT_DoLog DEBUG
    done

    # Ha. cygwin host have an .exe suffix (extension) for executables.
    [ "${CT_KERNEL}" = "cygwin" ] && EXEEXT=".exe" || EXEEXT=""

    # Transform the ARCH into a kernel-understandable ARCH
    case "${CT_ARCH}" in
        x86) CT_KERNEL_ARCH=i386;;
        ppc) CT_KERNEL_ARCH=powerpc;;
        *)   CT_KERNEL_ARCH="${CT_ARCH}";;
    esac

    # Build up the TARGET_CFLAGS from user-provided options
    # Override with user-specified CFLAGS
    [ -n "${CT_ARCH_CPU}" ]  && CT_TARGET_CFLAGS="-mcpu=${CT_ARCH_CPU} ${CT_TARGET_CFLAGS}"
    [ -n "${CT_ARCH_TUNE}" ] && CT_TARGET_CFLAGS="-mtune=${CT_ARCH_TUNE} ${CT_TARGET_CFLAGS}"
    [ -n "${CT_ARCH_ARCH}" ] && CT_TARGET_CFLAGS="-march=${CT_ARCH_ARCH} ${CT_TARGET_CFLAGS}"
    [ -n "${CT_ARCH_FPU}" ]  && CT_TARGET_CFLAGS="-mfpu=${CT_ARCH_FPU} ${CT_TARGET_CFLAGS}"

    # Help gcc
    CT_CFLAGS_FOR_HOST=
    [ "${CT_USE_PIPES}" = "y" ] && CT_CFLAGS_FOR_HOST="${CT_CFLAGS_FOR_HOST} -pipe"

    # And help make go faster
    PARALLELMFLAGS=
    [ ${CT_PARALLEL_JOBS} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -j${CT_PARALLEL_JOBS}"
    [ ${CT_LOAD} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -l${CT_LOAD}"

    CT_DoStep EXTRA "Dumping internal crosstool-NG configuration"
    CT_DoLog EXTRA "Building a toolchain for:"
    CT_DoLog EXTRA "  build  = ${CT_BUILD}"
    CT_DoLog EXTRA "  host   = ${CT_HOST}"
    CT_DoLog EXTRA "  target = ${CT_TARGET}"
    set |egrep '^CT_.+=' |sort |CT_DoLog DEBUG
    CT_EndStep
fi

# Include sub-scripts instead of calling them: that way, we do not have to
# export any variable, nor re-parse the configuration and functions files.
. "${CT_TOP_DIR}/scripts/build/kernel_${CT_KERNEL}.sh"
. "${CT_TOP_DIR}/scripts/build/binutils.sh"
. "${CT_TOP_DIR}/scripts/build/libfloat.sh"
. "${CT_TOP_DIR}/scripts/build/libc_${CT_LIBC}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_core_${CT_CC_CORE}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_${CT_CC}.sh"
. "${CT_TOP_DIR}/scripts/build/debug.sh"
. "${CT_TOP_DIR}/scripts/build/tools.sh"

if [ -z "${CT_RESTART}" ]; then
    CT_DoStep INFO "Retrieving needed toolchain components' tarballs"
    do_kernel_get
    do_binutils_get
    do_cc_core_get
    do_libfloat_get
    do_libc_get
    do_cc_get
    do_tools_get
    do_debug_get
    CT_EndStep

    if [ "${CT_ONLY_DOWNLOAD}" != "y" ]; then
        if [ "${CT_FORCE_EXTRACT}" = "y" ]; then
            mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
            nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1
        fi
        CT_DoStep INFO "Extracting and patching toolchain components"
        do_kernel_extract
        do_binutils_extract
        do_cc_core_extract
        do_libfloat_extract
        do_libc_extract
        do_cc_extract
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
    for step in libc_check_config       \
                kernel_check_config     \
                kernel_headers          \
                binutils                \
                cc_core_pass_1          \
                libc_headers            \
                libc_start_files        \
                cc_core_pass_2          \
                libfloat                \
                libc                    \
                cc                      \
                libc_finish             \
                tools                   \
                debug                   \
                ; do
        if [ ${do_it} -eq 0 ]; then
            if [ "${CT_RESTART}" = "${step}" ]; then
                CT_DoLoadState "${step}"
                do_it=1
                do_stop=0
            fi
        else
            CT_DoSaveState ${step}
            if [ ${do_stop} -eq 1 ]; then
                CT_DoLog ERROR "Stopping just after step \"${prev_step}\", as requested."
                exit 0
            fi
        fi
        if [ ${do_it} -eq 1 ]; then
            do_${step}
            if [ "${CT_STOP}" = "${step}" ]; then
                do_stop=1
            fi
            if [ "${CTDEBUG_CT_PAUSE_STEPS}" = "y" ]; then
                CT_DoPause "Step \"${step}\" finished"
            fi
        fi
        prev_step="${step}"
    done

    # Create the aliases to the target tools
    if [ -n "${CT_TARGET_ALIAS}" ]; then
        CT_DoLog EXTRA "Creating symlinks from \"${CT_TARGET}-*\" to \"${CT_TARGET_ALIAS}-*\""
        CT_Pushd "${CT_PREFIX_DIR}/bin"
        for t in "${CT_TARGET}-"*; do
            _t="`echo \"$t\" |sed -r -e 's/^'\"${CT_TARGET}\"'-/'\"${CT_TARGET_ALIAS}\"'-/;'`"
            CT_DoLog DEBUG "Linking \"${_t}\" -> \"${t}\""
            ln -s "${t}" "${_t}"
        done
        CT_Popd
    fi

    # Remove the generated documentation files
    if [ "${CT_REMOVE_DOCS}" = "y" ]; then
    	CT_DoLog INFO "Removing installed documentation"
        rm -rf "${CT_PREFIX_DIR}/"{,usr/}{man,info}
        rm -rf "${CT_SYSROOT_DIR}/"{,usr/}{man,info}
        rm -rf "${CT_DEBUG_INSTALL_DIR}/"{,usr/}{man,info}
    fi

    CT_DoLog EXTRA "Removing access to the build system tools"
    find "${CT_PREFIX_DIR}/bin" -name "${CT_BUILD}-"'*' -exec rm -fv {} \+ |CT_DoLog DEBUG
    find "${CT_PREFIX_DIR}/bin" -name "${CT_UNIQ_BUILD}-"'*' -exec rm -fv {} \+ |CT_DoLog DEBUG
    find "${CT_PREFIX_DIR}/bin" -name "${CT_HOST}-"'*' -exec rm -fv {} \+ |CT_DoLog DEBUG
fi

# OK, now we're done, set the toolchain read-only
# Don't log, the log file may become read-only any moment...
chmod -R a-w "${CT_INSTALL_DIR}"

# We still have some small bits to log
chmod u+w "${CT_LOG_FILE}"

CT_DoEnd INFO

# All files should now be read-only, log file included
chmod a-w "${CT_LOG_FILE}"

trap - EXIT
