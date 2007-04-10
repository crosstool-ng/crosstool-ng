# This scripts calls each component's build script.
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Parse all build files to have the needed functions.
. "${CT_TOP_DIR}/scripts/build/kernel_${CT_KERNEL}.sh"
. "${CT_TOP_DIR}/scripts/build/binutils.sh"
. "${CT_TOP_DIR}/scripts/build/libc_libfloat.sh"
. "${CT_TOP_DIR}/scripts/build/libc_${CT_LIBC}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_core_${CT_CC_CORE}.sh"
. "${CT_TOP_DIR}/scripts/build/cc_${CT_CC}.sh"

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

# Ah! Recent versions of binutils need some of the build system (read CT_BUILD)
# tools to be accessible (ar is but an example). Do that:
CT_DoLog EXTRA "Making build system tools available"
mkdir -p "${CT_PREFIX_DIR}/bin"
for tool in ar; do
    ln -s "`which ${tool}`" "${CT_PREFIX_DIR}/bin/${CT_BUILD}-${tool}"
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
tmp_target_CFLAGS=
[ -n "${CT_ARCH_CPU}" ]  && tmp_target_CFLAGS="${tmp_target_CFLAGS} -mcpu=${CT_ARCH_CPU}"
[ -n "${CT_ARCH_TUNE}" ] && tmp_target_CFLAGS="${tmp_target_CFLAGS} -mtune=${CT_ARCH_TUNE}"
[ -n "${CT_ARCH_ARCH}" ] && tmp_target_CFLAGS="${tmp_target_CFLAGS} -march=${CT_ARCH_ARCH}"
[ -n "${CT_ARCH_FPU}" ]  && tmp_target_CFLAGS="${tmp_target_CFLAGS} -mfpu=${CT_ARCH_FPU}"
# Override with user-specified CFLAGS
CT_TARGET_CFLAGS="${tmp_target_CFLAGS} ${CT_TARGET_CFLAGS}"

# Help gcc
CT_CFLAGS_FOR_HOST=
[ "${CT_USE_PIPES}" = "y" ] && CT_CFLAGS_FOR_HOST="${CT_CFLAGS_FOR_HOST} -pipe"

# And help make go faster
PARALLELMFLAGS=
[ ${CT_PARALLEL_JOBS} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -j${CT_PARALLEL_JOBS}"
[ ${CT_LOAD} -ne 0 ] && PARALLELMFLAGS="${PARALLELMFLAGS} -l${CT_LOAD}"

CT_DoStep EXTRA "Dumping internal crosstool-NG configuration"
CT_DoLog EXTRA "Building a toolchain for :"
CT_DoLog EXTRA "  build  = ${CT_BUILD}"
CT_DoLog EXTRA "  host   = ${CT_HOST}"
CT_DoLog EXTRA "  target = ${CT_TARGET}"
set |egrep '^CT_.+=' |sort |CT_DoLog DEBUG
CT_EndStep

# Now for the job by itself.
# Check the C library config ASAP, before the user gets bored, and is
# gone having his/her coffee
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
