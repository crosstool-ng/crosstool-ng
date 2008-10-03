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

CT_STAR_DATE=$(CT_DoDate +%s%N)
CT_STAR_DATE_HUMAN=$(CT_DoDate +%Y%m%d.%H%M%S)

# Are we configured? We'll need that later...
CT_TestOrAbort "Configuration file not found. Please create one." -f "${CT_TOP_DIR}/.config"

# Parse the configuration file
# It has some info about the logging facility, so include it early
. "${CT_TOP_DIR}/.config"

# Yes! We can do full logging from now on!
CT_DoLog INFO "Build started ${CT_STAR_DATE_HUMAN}"

# renice oursleves
CT_DoExecLog DEBUG renice ${CT_NICE} $$

CT_DoStep DEBUG "Dumping user-supplied crosstool-NG configuration"
cat "${CT_TOP_DIR}/.config" |egrep '^(# |)CT_' |CT_DoLog DEBUG
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
GREP_OPTIONS=

CT_DoLog INFO "Building environment variables"

# Parse architecture-specific functions
. "${CT_LIB_DIR}/config/arch/${CT_ARCH}/functions"

# Target tuple: CT_TARGET needs a little love:
CT_DoBuildTargetTuple

# Kludge: If any of the configured options needs CT_TARGET,
# then rescan the options file now:
. "${CT_TOP_DIR}/.config"

# Second kludge: merge user-supplied target CFLAGS with architecture-provided
# target CFLAGS. Do the same for LDFLAGS in case it happens in the future.
# Put user-supplied flags at the end, so that they take precedence.
CT_TARGET_CFLAGS="${CT_ARCH_TARGET_CFLAGS} ${CT_TARGET_CFLAGS}"
CT_TARGET_LDFLAGS="${CT_ARCH_TARGET_LDFLAGS} ${CT_TARGET_LDFLAGS}"
CT_CC_CORE_EXTRA_CONFIG="${CT_ARCH_CC_CORE_EXTRA_CONFIG} ${CT_CC_CORE_EXTRA_CONFIG}"
CT_CC_EXTRA_CONFIG="${CT_ARCH_CC_EXTRA_CONFIG} ${CT_CC_EXTRA_CONFIG}"

# Now, build up the variables from the user-configured options.
CT_KERNEL_FILE="${CT_KERNEL}-${CT_KERNEL_VERSION}"
CT_BINUTILS_FILE="binutils-${CT_BINUTILS_VERSION}"
CT_GMP_FILE="gmp-${CT_GMP_VERSION}"
CT_MPFR_FILE="mpfr-${CT_MPFR_VERSION}"
CT_CC_FILE="${CT_CC}-${CT_CC_VERSION}"
CT_LIBC_FILE="${CT_LIBC}-${CT_LIBC_VERSION}"

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

if [ -n "${CT_LOCAL_TARBALLS_DIR}" ]; then
    # Make absolute path, it so much easier!
    CT_LOCAL_TARBALLS_DIR=$(CT_MakeAbsolutePath "${CT_LOCAL_TARBALLS_DIR}")
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
    mv "${CT_BUILD_DIR}" "${CT_BUILD_DIR}.$$"
    chmod -R u+w "${CT_BUILD_DIR}.$$"
    setsid nohup rm -rf "${CT_BUILD_DIR}.$$" >/dev/null 2>&1 &
fi

# Don't eradicate directories if we need to restart
if [ -z "${CT_RESTART}" ]; then
    # Get rid of pre-existing installed toolchain and previous build directories.
    # We need to do that _before_ we can safely log, because the log file will
    # most probably be in the toolchain directory.
    if [ "${CT_FORCE_DOWNLOAD}" = "y" -a -d "${CT_TARBALLS_DIR}" ]; then
        mv "${CT_TARBALLS_DIR}" "${CT_TARBALLS_DIR}.$$"
        chmod -R u+w "${CT_TARBALLS_DIR}.$$"
        setsid nohup rm -rf "${CT_TARBALLS_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ "${CT_FORCE_EXTRACT}" = "y" -a -d "${CT_SRC_DIR}" ]; then
        mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
        chmod -R u+w "${CT_SRC_DIR}.$$"
        setsid nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ -d "${CT_INSTALL_DIR}" ]; then
        mv "${CT_INSTALL_DIR}" "${CT_INSTALL_DIR}.$$"
        chmod -R u+w "${CT_INSTALL_DIR}.$$"
        setsid nohup rm -rf "${CT_INSTALL_DIR}.$$" >/dev/null 2>&1 &
    fi
    if [ -d "${CT_DEBUG_INSTALL_DIR}" ]; then
        mv "${CT_DEBUG_INSTALL_DIR}" "${CT_DEBUG_INSTALL_DIR}.$$"
        chmod -R u+w "${CT_DEBUG_INSTALL_DIR}.$$"
        setsid nohup rm -rf "${CT_DEBUG_INSTALL_DIR}.$$" >/dev/null 2>&1 &
    fi
    # In case we start anew, get rid of the previously saved state directory
    if [ -d "${CT_STATE_DIR}" ]; then
        mv "${CT_STATE_DIR}" "${CT_STATE_DIR}.$$"
        chmod -R u+w "${CT_STATE_DIR}.$$"
        setsid nohup rm -rf "${CT_STATE_DIR}.$$" >/dev/null 2>&1 &
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
# the previous build was successful. To be able to move the logfile there,
# switch them back to read/write
chmod -R u+w "${CT_INSTALL_DIR}" "${CT_PREFIX_DIR}"

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
    # Determine build system if not set by the user
    CT_Test "You did not specify the build system. That's OK, I can guess..." -z "${CT_BUILD}"
    CT_BUILD="${CT_BUILD:-$(CT_DoConfigGuess)}"
    CT_BUILD=$(CT_DoConfigSub "${CT_BUILD}")

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

    # Prevent gcc from installing its libraries outside of the sys-root
    ln -sf "sys-root/lib" "${CT_PREFIX_DIR}/${CT_TARGET}/lib"

    # Now, in case we're 64 bits, just have lib64/ be a symlink to lib/
    # so as to have all libraries in the same directory (we can do that
    # because we are *not* multilib).
    case "${CT_TARGET}" in
        powerpc64*|ppc64*|x86_64*)
            ln -sf "lib" "${CT_SYSROOT_DIR}/lib64"
            ln -sf "lib" "${CT_SYSROOT_DIR}/usr/lib64"
            ln -sf "sys-root/lib" "${CT_PREFIX_DIR}/${CT_TARGET}/lib64"
            ;;
    esac

    # Canadian-cross are really picky on the way they are built. Tweak the values.
    CT_UNIQ_BUILD=$(echo "${CT_BUILD}" |sed -r -e 's/-/-build_/')
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
        *,y)      CT_HOST=$(echo "${CT_HOST}" |sed -r -e 's/-/-host_/;');;
    esac

    # Ah! Recent versions of binutils need some of the build and/or host system
    # (read CT_BUILD and CT_HOST) tools to be accessible (ar is but an example).
    # Do that:
    CT_DoLog DEBUG "Making build system tools available"
    mkdir -p "${CT_PREFIX_DIR}/bin"
    for tool in ar as dlltool ${CT_CC_NATIVE:=gcc} gnatbind gnatmake ld nm ranlib strip windres objcopy objdump; do
        tmp=$(CT_Which ${tool})
        if [ -n "${tmp}" ]; then
            ln -sfv "${tmp}" "${CT_PREFIX_DIR}/bin/${CT_BUILD}-${tool}"
            ln -sfv "${tmp}" "${CT_PREFIX_DIR}/bin/${CT_UNIQ_BUILD}-${tool}"
            ln -sfv "${tmp}" "${CT_PREFIX_DIR}/bin/${CT_HOST}-${tool}"
        fi |CT_DoLog DEBUG
    done

    # Some makeinfo versions are a pain in [put your most sensible body part here].
    # Go ahead with those, by creating a wrapper that keeps partial files, and that
    # never fails:
    echo -e "#!/bin/sh\n$(CT_Which makeinfo) --force \"\${@}\"\ntrue" >"${CT_PREFIX_DIR}/bin/makeinfo"
    chmod 700 "${CT_PREFIX_DIR}/bin/makeinfo"

    # Help gcc
    CT_CFLAGS_FOR_HOST=
    [ "${CT_USE_PIPES}" = "y" ] && CT_CFLAGS_FOR_HOST="${CT_CFLAGS_FOR_HOST} -pipe"

    # Override the configured jobs with what's been given on the command line
    [ -n "${CT_JOBS}" ] && CT_PARALLEL_JOBS="${CT_JOBS}"

    # Help ./configure scripts go faster
    [ "${CT_CONFIG_SHELL_ASH}" = "y" ] && export CONFIG_SHELL=/bin/ash
    export CONFIG_SHELL

    # And help make go faster
    PARALLELMFLAGS=
    [ ${CT_PARALLEL_JOBS} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -j${CT_PARALLEL_JOBS}"
    [ ${CT_LOAD} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -l${CT_LOAD}"
    export PARALLELMFLAGS

    CT_DoLog EXTRA "Installing user-supplied crosstool-NG configuration"
    CT_DoExecLog DEBUG install -m 0755 "${CT_LIB_DIR}/tools/toolchain-config.in" "${CT_PREFIX_DIR}/bin/${CT_TARGET}.ct-ng.config"
    bzip2 -c -9 .config >>"${CT_PREFIX_DIR}/bin/${CT_TARGET}.ct-ng.config"

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
. "${CT_LIB_DIR}/scripts/build/kernel/${CT_KERNEL}.sh"
. "${CT_LIB_DIR}/scripts/build/gmp.sh"
. "${CT_LIB_DIR}/scripts/build/mpfr.sh"
. "${CT_LIB_DIR}/scripts/build/binutils.sh"
. "${CT_LIB_DIR}/scripts/build/libc/${CT_LIBC}.sh"
. "${CT_LIB_DIR}/scripts/build/cc/${CT_CC}.sh"
. "${CT_LIB_DIR}/scripts/build/debug.sh"
. "${CT_LIB_DIR}/scripts/build/tools.sh"

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
            mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.force.$$"
            setsid nohup rm -rf "${CT_SRC_DIR}.force.$$" >/dev/null 2>&1
            mkdir -p "${CT_SRC_DIR}"
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

    CT_DoLog INFO "================================================================="

    CT_DoLog DEBUG "Removing access to the build system tools"
    find "${CT_PREFIX_DIR}/bin" -name "${CT_BUILD}-"'*' -exec rm -fv {} \; |CT_DoLog DEBUG
    find "${CT_PREFIX_DIR}/bin" -name "${CT_UNIQ_BUILD}-"'*' -exec rm -fv {} \; |CT_DoLog DEBUG
    find "${CT_PREFIX_DIR}/bin" -name "${CT_HOST}-"'*' -exec rm -fv {} \; |CT_DoLog DEBUG
    rm -fv "${CT_PREFIX_DIR}/bin/makeinfo" |CT_DoLog DEBUG

    if [ "${CT_BARE_METAL}" != "y" ]; then
        CT_DoLog EXTRA "Installing the populate helper"
        sed -r -e 's|@@CT_TARGET@@|'"${CT_TARGET}"'|g;' \
            "${CT_LIB_DIR}/tools/populate.in"           \
            >"${CT_PREFIX_DIR}/bin/${CT_TARGET}-populate"
        chmod 755 "${CT_PREFIX_DIR}/bin/${CT_TARGET}-populate"
    fi

    # Create the aliases to the target tools
    CT_DoLog EXTRA "Creating toolchain aliases"
    CT_Pushd "${CT_PREFIX_DIR}/bin"
    for t in "${CT_TARGET}-"*; do
        if [ -n "${CT_TARGET_ALIAS}" ]; then
            _t=$(echo "$t" |sed -r -e 's/^'"${CT_TARGET}"'-/'"${CT_TARGET_ALIAS}"'-/;')
            ln -sv "${t}" "${_t}" 2>&1
        fi
        if [ -n "${CT_TARGET_ALIAS_SED_EXPR}" ]; then
            _t=$(echo "$t" |sed -r -e "${CT_TARGET_ALIAS_SED_EXPR}")
            ln -sv "${t}" "${_t}" 2>&1
        fi
    done |CT_DoLog ALL
    CT_Popd

    # Remove the generated documentation files
    if [ "${CT_REMOVE_DOCS}" = "y" ]; then
    	CT_DoLog INFO "Removing installed documentation"
        rm -rf "${CT_PREFIX_DIR}/"{,usr/}{man,info}
        rm -rf "${CT_SYSROOT_DIR}/"{,usr/}{man,info}
        rm -rf "${CT_DEBUG_INSTALL_DIR}/"{,usr/}{man,info}
    fi
fi

CT_DoEnd INFO

if [ "${CT_LOG_FILE_COMPRESS}" = y ]; then
    CT_DoLog EXTRA "Compressing log file"
    exec >/dev/null
    bzip2 -9 "${CT_LOG_FILE}"
fi

if [ "${CT_INSTALL_DIR_RO}" = "y" ]; then
    # OK, now we're done, set the toolchain read-only
    # Don't log, the log file may become read-only any moment...
    chmod -R a-w "${CT_INSTALL_DIR}" >/dev/null 2>&1
fi

trap - EXIT
