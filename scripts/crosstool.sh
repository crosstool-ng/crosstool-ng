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
# and checks for needed tools. It eventually calls the main build script.

# User must set CT_TOP_DIR in is environment!
# Once we can build out-of-tree, then this will have to go.
if [ -z "${CT_TOP_DIR}" -o ! -d "${CT_TOP_DIR}" ]; then
    # We don't have the functions right now, because we don't have CT_TOP_DIR.
    # Do the print stuff by hand:
    echo "CT_TOP_DIR not set. You must set CT_TOP_DIR to the top directory where crosstool is installed."
    exit 1
fi

# Parse the common functions
. "${CT_TOP_DIR}/scripts/functions"

CT_STAR_DATE=`CT_DoDate +%s%N`
CT_STAR_DATE_HUMAN=`CT_DoDate +%Y%m%d.%H%M%S`

# Log to a temporary file until we have built our environment
CT_ACTUAL_LOG_FILE="${CT_TOP_DIR}/$$.log"

# CT_TOP_DIR should be an absolute path.
CT_TOP_DIR="`CT_MakeAbsolutePath \"${CT_TOP_DIR}\"`"

# Parse the configuration file
CT_TestOrAbort "Configuration file not found. Please create one." -f "${CT_TOP_DIR}/.config"
. "${CT_TOP_DIR}/.config"

# The progress bar indicator is asked for
if [ "${CT_LOG_PROGRESS_BAR}" = "y" ]; then
    _CT_PROG_BAR() {
        [ $((cpt/5)) -eq 0 ] && echo -en "/"
        [ $((cpt/5)) -eq 1 ] && echo -en "-"
        [ $((cpt/5)) -eq 2 ] && echo -en "\\"
        [ $((cpt/5)) -eq 3 ] && echo -en "|"
        echo -en "\r"
        cpt=$(((cpt+1)%20))
    }
    CT_PROG_BAR=_CT_PROG_BAR
    export -f _CT_PROG_BAR
else
    CT_PROG_BAR=
fi

# Apply the color scheme if needed
if [ "${CT_LOG_USE_COLORS}" = "y" ]; then
    CT_ERROR_COLOR="${_A_NOR}${_A_BRI}${_F_RED}"
    CT_WARN_COLOR="${_A_NOR}${_A_BRI}${_F_YEL}"
    CT_INFO_COLOR="${_A_NOR}${_A_BRI}${_F_GRN}"
    CT_EXTRA_COLOR="${_A_NOR}${_A_DIM}${_F_GRN}"
    CT_DEBUG_COLOR="${_A_NOR}${_A_DIM}${_F_WHI}"
    CT_NORMAL_COLOR="${_A_NOR}"
else
    CT_ERROR_COLOR=
    CT_WARN_COLOR=
    CT_INFO_COLOR=
    CT_EXTRA_COLOR=
    CT_DEBUG_COLOR=
    CT_NORMAL_COLOR=
fi

# Yes! We can do full logging from now on!
CT_DoLog INFO "Build started ${CT_STAR_DATE_HUMAN}"

# renice oursleves
renice ${CT_NICE} $$ |CT_DoLog DEBUG

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

CT_DoStep DEBUG "Dumping crosstool-NG configuration"
cat ${CT_TOP_DIR}/.config |egrep '^(# |)CT_' |CT_DoLog DEBUG
CT_EndStep

CT_DoLog INFO "Building environment variables"

# Target triplet: CT_TARGET needs a little love:
CT_DoBuildTargetTriplet

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
[ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ] && CT_LIBFLOAT_FILE="libfloat-990616"

# Kludge: If any of the configured options needs CT_TARGET or CT_TOP_DIR,
# then rescan the options file now:
. "${CT_TOP_DIR}/.config"

# Some more sanity checks now that we have all paths set up
case "${CT_TARBALLS_DIR},${CT_SRC_DIR},${CT_BUILD_DIR},${CT_PREFIX_DIR},${CT_INSTALL_DIR}" in
    *" "*) CT_Abort "Don't use spaces in paths, it breaks things.";;
esac

# Note: we'll always install the core compiler in its own directory, so as to
# not mix the two builds: core and final. Anyway, its generic, wether we use
# a different compiler as core, or not.
CT_CC_CORE_PREFIX_DIR="${CT_BUILD_DIR}/${CT_CC}-core"

# Good, now grab a bit of informations on the system we're being run,
# just in case something goes awok, and it's not our fault:
CT_SYS_HOSTNAME=`hostname -f 2>/dev/null || true`
# Hmmm. Some non-DHCP-enabled machines do not have an FQDN... Fall back to node name.
CT_SYS_HOSTNAME="${CT_SYS_HOSTNAME:-`uname -n`}"
CT_SYS_KERNEL=`uname -s`
CT_SYS_REVISION=`uname -r`
# MacOS X lacks '-o' :
CT_SYS_OS=`uname -o || echo "Unknown (maybe MacOS-X)"`
CT_SYS_MACHINE=`uname -m`
CT_SYS_PROCESSOR=`uname -p`
CT_SYS_USER="`id -un`"
CT_SYS_DATE=`CT_DoDate +%Y%m%d.%H%M%S`
CT_SYS_GCC=`gcc -dumpversion`
CT_TOOLCHAIN_ID="crosstool-${CT_VERSION} build ${CT_SYS_DATE} by ${CT_SYS_USER}@${CT_SYS_HOSTNAME} for ${CT_TARGET}"

# Check now if we can write to the destination directory:
if [ -d "${CT_INSTALL_DIR}" ]; then
    CT_TestAndAbort "Destination directory \"${CT_INSTALL_DIR}\" is not removable" ! -w `dirname "${CT_INSTALL_DIR}"`
fi

# Get rid of pre-existing installed toolchain and previous build directories.
# We need to do that _before_ we can safely log, because the log file will
# most probably be in the toolchain directory.
if [ -d "${CT_INSTALL_DIR}" ]; then
    mv "${CT_INSTALL_DIR}" "${CT_INSTALL_DIR}.$$"
    nohup rm -rf "${CT_INSTALL_DIR}.$$" >/dev/null 2>&1 &
fi
if [ -d "${CT_BUILD_DIR}" ]; then
    mv "${CT_BUILD_DIR}" "${CT_BUILD_DIR}.$$"
    nohup rm -rf "${CT_BUILD_DIR}.$$" >/dev/null 2>&1 &
fi
if [ "${CT_FORCE_EXTRACT}" = "y" -a -d "${CT_SRC_DIR}" ]; then
    mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
    nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1 &
fi
mkdir -p "${CT_INSTALL_DIR}"
mkdir -p "${CT_BUILD_DIR}"
mkdir -p "${CT_TARBALLS_DIR}"
mkdir -p "${CT_SRC_DIR}"

# Make all path absolute, it so much easier!
# Now we have had the directories created, we even will get rid of embedded .. in paths:
CT_SRC_DIR="`CT_MakeAbsolutePath \"${CT_SRC_DIR}\"`"
CT_TARBALLS_DIR="`CT_MakeAbsolutePath \"${CT_TARBALLS_DIR}\"`"

# Redirect log to the actual log file now we can
# It's quite understandable that the log file will be installed in the install
# directory, so we must first ensure it exists and is writeable (above) before
# we can log there
case "${CT_LOG_TO_FILE},${CT_LOG_FILE}" in
    ,*)   rm -f "${CT_ACTUAL_LOG_FILE}"
          CT_ACTUAL_LOG_FILE=/dev/null
          ;;
    y,/*) mkdir -p "`dirname \"${CT_LOG_FILE}\"`"
          mv "${CT_ACTUAL_LOG_FILE}" "${CT_LOG_FILE}"
          CT_ACTUAL_LOG_FILE="${CT_LOG_FILE}"
          ;;
    y,*)  mkdir -p "`pwd`/`dirname \"${CT_LOG_FILE}\"`"
          mv "${CT_ACTUAL_LOG_FILE}" "`pwd`/${CT_LOG_FILE}"
          CT_ACTUAL_LOG_FILE="`pwd`/${CT_LOG_FILE}"
          ;;
esac

# Determine build system if not set by the user
CT_Test "You did not specify the build system. Guessing." -z "${CT_BUILD}"
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
if [ "${CT_CANADIAN}" = "y" ]; then
    # Arrange so that gcc never, ever think that build system == host system
    CT_CANADIAN_OPT="--build=`echo \"${CT_BUILD}\" |sed -r -e 's/-/-build_/'`"
    # We shall have a compiler for this target!
    # Do test here...
else
    CT_HOST="${CT_BUILD}"
    CT_CANADIAN_OPT=
    # Add the target toolchain in the path so that we can build the C library
    export PATH="${CT_PREFIX_DIR}/bin:${CT_CC_CORE_PREFIX_DIR}/bin:${PATH}"
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
    *)        CT_HOST="`echo \"${CT_HOST}\" |sed -r -e 's/-/-host_/;'`";;
esac

# Ah! Recent versions of binutils need some of the build and/or host system
# (read CT_BUILD and CT_HOST) tools to be accessible (ar is but an example).
# Do that:
CT_DoLog EXTRA "Making build system tools available"
mkdir -p "${CT_PREFIX_DIR}/bin"
for tool in ar; do
    ln -s "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_BUILD}-${tool}"
    ln -s "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_HOST}-${tool}"
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

# Include sub-scripts instead of calling them: that way, we do not have to
# export any variable, nor re-parse the configuration and functions files.
. "${CT_TOP_DIR}/scripts/build/kernel_${CT_KERNEL}.sh"
. "${CT_TOP_DIR}/scripts/build/binutils.sh"
. "${CT_TOP_DIR}/scripts/build/libc_libfloat.sh"
. "${CT_TOP_DIR}/scripts/build/libc_${CT_LIBC}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_core_${CT_CC_CORE}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_${CT_CC}.sh"

# Now for the job by itself. Go have a coffee!
if [ "${CT_NO_DOWNLOAD}" != "y" ]; then
	CT_DoStep INFO "Retrieving needed toolchain components' tarballs"
    do_kernel_get
    do_binutils_get
    do_libc_get
    do_libfloat_get
    do_cc_core_get
    do_cc_get
    CT_EndStep
fi

if [ "${CT_ONLY_DOWNLOAD}" != "y" ]; then
    if [ "${CT_FORCE_EXTRACT}" = "y" ]; then
        mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
        nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1
    fi
    CT_DoStep INFO "Extracting and patching toolchain components"
    do_kernel_extract
    do_binutils_extract
    do_libc_extract
    do_libfloat_extract
    do_cc_core_extract
    do_cc_extract
    CT_EndStep

    if [ "${CT_ONLY_EXTRACT}" != "y" ]; then
        do_libc_check_config
        do_kernel_check_config
        do_kernel_headers
        do_binutils
        do_libc_headers
        do_cc_core
        do_libfloat
        do_libc
        do_cc
        do_libc_finish
    fi
fi

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

if [ "${CT_REMOVE_DOCS}" = "y" ]; then
	CT_DoLog INFO "Removing installed documentation"
    rm -rf "${CT_PREFIX_DIR}/"{man,info}
fi

CT_STOP_DATE=`CT_DoDate +%s%N`
CT_STOP_DATE_HUMAN=`CT_DoDate +%Y%m%d.%H%M%S`
CT_DoLog INFO "Build completed at ${CT_STOP_DATE_HUMAN}"
elapsed=$((CT_STOP_DATE-CT_STAR_DATE))
elapsed_min=$((elapsed/(60*1000*1000*1000)))
elapsed_sec=`printf "%02d" $(((elapsed%(60*1000*1000*1000))/(1000*1000*1000)))`
elapsed_csec=`printf "%02d" $(((elapsed%(1000*1000*1000))/(10*1000*1000)))`
CT_DoLog INFO "(elapsed: ${elapsed_min}:${elapsed_sec}.${elapsed_csec})"

# Restore a 'normal' color setting
echo -en "${CT_NORMAL_COLOR}"

trap - EXIT
