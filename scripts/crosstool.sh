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
CT_ACTUAL_LOG_FILE="`pwd`/$$.log"

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

# This should go in buildToolchain.sh, but we might need it because it could
# be used by the user in his/her paths definitions.
# Target triplet: CT_TARGET needs a little love:
case "${CT_ARCH_BE},${CT_ARCH_LE}" in
    y,) target_endian_eb=eb; target_endian_el=;;
    ,y) target_endian_eb=; target_endian_el=el;;
esac
case "${CT_ARCH}" in
    arm)  CT_TARGET="${CT_ARCH}${target_endian_eb}";;
    mips) CT_TARGET="${CT_ARCH}${target_endian_el}";;
    x86*) # Much love for this one :-(
          # Ultimately, we should use config.sub to output the correct
          # procesor name. Work for later...
          arch="${CT_ARCH_ARCH}"
          [ -z "${arch}" ] && arch="${CT_ARCH_TUNE}"
          case "${CT_ARCH}" in
              x86_64)      CT_TARGET=x86_64;;
          	  *)  case "${arch}" in
                      "")                                       CT_TARGET=i386;;
                      i386|i486|i586|i686)                      CT_TARGET="${arch}";;
                      winchip*)                                 CT_TARGET=i486;;
                      pentium|pentium-mmx|c3*)                  CT_TARGET=i586;;
                      nocona|athlon*64|k8|athlon-fx|opteron)    CT_TARGET=x86_64;;
                      pentiumpro|pentium*|athlon*)              CT_TARGET=i686;;
                      *)                                        CT_TARGET=i586;;
                  esac;;
          esac;;
esac
case "${CT_TARGET_VENDOR}" in
    "") CT_TARGET="${CT_TARGET}-unknown";;
    *)  CT_TARGET="${CT_TARGET}-${CT_TARGET_VENDOR}";;
esac
case "${CT_KERNEL}" in
    linux*)  CT_TARGET="${CT_TARGET}-linux";;
    cygwin*) CT_TARGET="${CT_TARGET}-cygwin";;
esac
case "${CT_LIBC}" in
    glibc)  CT_TARGET="${CT_TARGET}-gnu";;
    uClibc) CT_TARGET="${CT_TARGET}-uclibc";;
esac
case "${CT_ARCH_ABI}" in
    eabi)   CT_TARGET="${CT_TARGET}eabi";;
esac
CT_TARGET="`${CT_TOP_DIR}/tools/config.sub ${CT_TARGET}`"

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

# Determine build system if not set by the user
CT_Test "You did not specify the build system. Guessing." -z "${CT_BUILD}"
CT_BUILD="`${CT_TOP_DIR}/tools/config.sub \"${CT_BUILD:-\`${CT_TOP_DIR}/tools/config.guess\`}\"`"

# Get rid of pre-existing installed toolchain and previous build directories.
# We need to do that _before_ we can safely log, because the log file will
# most probably be in the toolchain directory.
if [ -d "${CT_PREFIX_DIR}" ]; then
    mv "${CT_PREFIX_DIR}" "${CT_PREFIX_DIR}.$$"
    nohup rm -rf "${CT_PREFIX_DIR}.$$" >/dev/null 2>&1 &
fi
mkdir -p "${CT_PREFIX_DIR}"
if [ -d "${CT_BUILD_DIR}" ]; then
    mv "${CT_BUILD_DIR}" "${CT_BUILD_DIR}.$$"
    nohup rm -rf "${CT_BUILD_DIR}.$$" >/dev/null 2>&1 &
fi
mkdir -p "${CT_BUILD_DIR}"

# Check now if we can write to the destination directory:
if [ -d "${CT_PREFIX_DIR}" ]; then
    CT_TestAndAbort "Destination directory \"${CT_INSTALL_DIR}\" is not writeable" ! -w "${CT_PREFIX_DIR}"
else
    mkdir -p "${CT_PREFIX_DIR}" || CT_Abort "Could not create destination directory \"${CT_PREFIX_DIR}\""
fi

# Redirect log to the actual log file now we can
# It's quite understandable that the log file will be installed in the
# install directory, so we must first ensure it exists and is writeable (above)
# before we can log there
t="${CT_ACTUAL_LOG_FILE}"
case "${CT_LOG_TO_FILE},${CT_LOG_FILE}" in
    ,*)   CT_ACTUAL_LOG_FILE=/dev/null
          rm -f "${t}"
          ;;
    y,/*) mkdir -p "`dirname \"${CT_LOG_FILE}\"`"
          CT_ACTUAL_LOG_FILE="${CT_LOG_FILE}"
          mv "${t}" "${CT_ACTUAL_LOG_FILE}"
          ;;
    y,*)  mkdir -p "`pwd`/`dirname \"${CT_LOG_FILE}\"`"
          CT_ACTUAL_LOG_FILE="`pwd`/${CT_LOG_FILE}"
          mv "${t}" "${CT_ACTUAL_LOG_FILE}"
          ;;
esac

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
CT_SYS_OS=`uname -o || echo Unkown`
CT_SYS_MACHINE=`uname -m`
CT_SYS_PROCESSOR=`uname -p`
CT_SYS_USER="`id -un`"
CT_SYS_DATE=`CT_DoDate +%Y%m%d.%H%M%S`
CT_SYS_GCC=`gcc -dumpversion`
CT_TOOLCHAIN_ID="crosstool-${CT_VERSION} build ${CT_SYS_DATE} by ${CT_SYS_USER}@${CT_SYS_HOSTNAME} for ${CT_TARGET}"

# renice oursleves
renice ${CT_NICE} $$ |CT_DoLog DEBUG

# Include sub-scripts instead of calling them: that way, we do not have to
# export any variable, nor re-parse the configuration and functions files.
. "${CT_TOP_DIR}/scripts/getExtractPatch.sh"
. "${CT_TOP_DIR}/scripts/buildToolchain.sh"
#. "${CT_TOP_DIR}/scripts/testToolchain.sh"

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
