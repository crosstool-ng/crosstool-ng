#!/bin/bash

# This scripts makes a tarball of the configured toolchain
# Pre-requisites:
#  - crosstool-NG is configured
#  - components tarball are available
#  - toolchain is built successfully

# We need the functions first:
. "${CT_TOP_DIR}/scripts/functions"

exec 6>&1
exec >/dev/null

# Parse the configuration file:
. ${CT_TOP_DIR}/.config

CT_DoBuildTargetTriplet

# Kludge: if any of the config options needs either CT_TARGET or CT_TOP_DIR,
# re-parse them:
. "${CT_TOP_DIR}/.config"

# Override log level
unset CT_LOG_ERROR CT_LOG_WARN CT_LOG_EXTRA CT_LOG_DEBUG
CT_LOG_INFO=y
CT_LOG_LEVEL_MAX="INFO"

# Build the files' base names
CT_KERNEL_FILE="${CT_KERNEL}-${CT_KERNEL_VERSION}"
CT_BINUTILS_FILE="binutils-${CT_BINUTILS_VERSION}"
CT_LIBC_FILE="${CT_LIBC}-${CT_LIBC_VERSION}"
for addon in ${CT_LIBC_ADDONS_LIST}; do
    CT_LIBC_ADDONS_FILES="${CT_LIBC_ADDONS_FILES} ${CT_LIBC}-${addon}-${CT_LIBC_VERSION}"
done
[ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && CT_LIBC_ADDONS_FILES="${CT_LIBC_ADDONS_FILES} ${CT_LIBC}-ports-${CT_LIBC_VERSION}"
[ "${CT_LIBC_UCLIBC_LOCALES}" = "y" ]  && CT_LIBC_ADDONS_FILES="${CT_LIBC_ADDONS_FILES} ${CT_LIBC}-locales-030818"
[ "${CT_CC_USE_CORE}" = "y" ]          && CT_CC_CORE_FILE="${CT_CC_CORE}-${CT_CC_CORE_VERSION}"
CT_CC_FILE="${CT_CC}-${CT_CC_VERSION}"
[ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ] && CT_LIBFLOAT_FILE="libfloat-990616"

# Build a one-line list of the files to ease scanning below
CT_TARBALLS_DIR="${CT_TOP_DIR}/targets/tarballs"
CT_TARBALLS=" "
for file_var in CT_KERNEL_FILE CT_BINUTILS_FILE CT_LIBC_FILE CT_LIBC_ADDONS_FILES CT_CC_CORE_FILE CT_CC_FILE CT_LIBFLOAT_FILE; do
    for file in ${!file_var}; do
        ext=`CT_GetFileExtension "${file}"`
        CT_TestAndAbort "Missing tarball for: \"${file}\"" -z "${ext}"
        CT_TARBALLS="${CT_TARBALLS}${file}${ext} "
    done
done

# We need to emulate a build directory:
CT_BUILD_DIR="${CT_TOP_DIR}/targets/${CT_TARGET}/build"
mkdir -p "${CT_BUILD_DIR}"
CT_MktempDir tempdir

# Save crosstool-ng, as it is configured for the current toolchain.
topdir=`basename "${CT_TOP_DIR}"`
CT_Pushd "${CT_TOP_DIR}/.."

botdir=`pwd`

# Build the list of files to exclude:
echo "${topdir}/log.*" >"${tempdir}/${CT_TARGET}.list"
echo "${topdir}/targets/*-*-*-*" >>"${tempdir}/${CT_TARGET}.list"
for t in `ls -1 "${topdir}/targets/tarballs/"`; do
    case "${CT_TARBALLS}" in
        *" ${t} "*) ;;
        *)          echo "${topdir}/targets/tarballs/${t}" >>"${tempdir}/${CT_TARGET}.list"
    esac
done

CT_DoLog INFO "Saving crosstool"
tar cfj "${CT_PREFIX_DIR}/${topdir}.${CT_TARGET}.tar.bzip2" \
    --no-wildcards-match-slash                              \
    -X "${tempdir}/${CT_TARGET}.list"                       \
    "${topdir}"                                             2>/dev/null

CT_Popd

# Save the generated toolchain
CT_DoLog INFO "Saving the generated toolchain"
tar cfj "${botdir}/${CT_TARGET}.tar.bz2" "${CT_PREFIX_DIR}" 2>/dev/null

rm -f "${CT_PREFIX_DIR}/${topdir}.${CT_TARGET}.tar.bzip2"
rm -rf "${tempdir}"
