#!/bin/bash

# This script is responsible for saving the current configuration into a
# sample to be used later on as a pre-configured target.

# What we need to save:
#  - the .config file
#  - the kernel .config file if specified
#  - the uClibc .config file if uClibc selected

. "${CT_TOP_DIR}/scripts/functions"

exec 6>&1
exec >/dev/null

# Parse the configuration file
CT_TestOrAbort "Configuration file not found. Please create one." -f "${CT_TOP_DIR}/.config"
. "${CT_TOP_DIR}/.config"

# Target triplet: CT_TARGET needs a little love:
CT_DoBuildTargetTriplet

# Kludge: if any of the config options needs either CT_TARGET or CT_TOP_DIR,
# re-parse them:
. "${CT_TOP_DIR}/.config"

# Override log level
unset CT_LOG_ERROR CT_LOG_WARN CT_LOG_EXTRA CT_LOG_DEBUG 
CT_LOG_INFO=y
CT_LOG_LEVEL_MAX="INFO"

# Create the sample directory
# In case it was manually made, add it to svn
if [ -d "${CT_TOP_DIR}/samples/${CT_TARGET}" ]; then
    # svn won't fail when adding a directory already managed by svn
    svn add "${CT_TOP_DIR}/samples/${CT_TARGET}" >/dev/null 2>&1
else
    svn mkdir "${CT_TOP_DIR}/samples/${CT_TARGET}" >/dev/null 2>&1
fi

# Save the crosstool-NG config file
cp "${CT_TOP_DIR}/.config" "${CT_TOP_DIR}/samples/${CT_TARGET}/crosstool.config"

# Function to copy a file to the sample directory
# Needed in case the file is already there (think of a previously available sample)
# Usage: CT_DoAddFileToSample <source> <dest>
CT_DoAddFileToSample() {
    source="$1"
    dest="$2"
    inode_s=`ls -i "${source}"`
    inode_d=`ls -i "${dest}" 2>/dev/null || true`
    if [ "${inode_s}" != "${inode_d}" ]; then
        cp "${source}" "${dest}"
    fi
    svn add "${dest}" >/dev/null 2>&1
}

# Save the kernel .config file
if [ -n "${CT_KERNEL_LINUX_CONFIG_FILE}" ]; then
    # We save the file, and then point the saved sample to this file
    CT_DoAddFileToSample "${CT_KERNEL_LINUX_CONFIG_FILE}" "${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_KERNEL}-${CT_KERNEL_VERSION}.config"
    sed -r -i -e 's|^(CT_KERNEL_LINUX_CONFIG_FILE=).+$|\1"${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_KERNEL}-${CT_KERNEL_VERSION}.config"|;' \
        "${CT_TOP_DIR}/samples/${CT_TARGET}/crosstool.config"
else
    # remove any dangling files
    for f in "${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_KERNEL}-"*.config; do
        if [ -f "${f}" ]; then svn rm --force "${f}" >/dev/null 2>&1; fi
    done
fi

# Save the uClibc .config file
if [ -n "${CT_LIBC_UCLIBC_CONFIG_FILE}" ]; then
    # We save the file, and then point the saved sample to this file
    CT_DoAddFileToSample "${CT_LIBC_UCLIBC_CONFIG_FILE}" "${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_LIBC}-${CT_LIBC_VERSION}.config"
    sed -r -i -e 's|^(CT_LIBC_UCLIBC_CONFIG_FILE=).+$|\1"${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_LIBC}-${CT_LIBC_VERSION}.config"|;' \
        "${CT_TOP_DIR}/samples/${CT_TARGET}/crosstool.config"
else
    # remove any dangling files
    for f in "${CT_TOP_DIR}/samples/${CT_TARGET}/${CT_LIBC}-"*.config; do
        if [ -f "${f}" ]; then svn rm --force "${f}" >/dev/null 2>&1; fi
    done
fi

# We could svn add earlier, but it's better to
# add a frozen file than modifying it later
svn add "${CT_TOP_DIR}/samples/${CT_TARGET}/crosstool.config" >/dev/null 2>&1

svn stat "${CT_TOP_DIR}/samples/${CT_TARGET}" 2>/dev/null |CT_DoLog INFO
