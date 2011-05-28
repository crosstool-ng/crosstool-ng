# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Add the definitions common to glibc and eglibc
#   do_libc_start_files
#   do_libc
#   do_libc_finish
#   do_libc_add_ons_list
#   do_libc_min_kernel_config
. "${CT_LIB_DIR}/scripts/build/libc/glibc-eglibc.sh-common"

# Download glibc
do_libc_get() {
    local date
    local version
    local -a addons_list

    addons_list=($(do_libc_add_ons_list " "))

    # Main source
    CT_GetFile "glibc-${CT_LIBC_VERSION}"               \
               {ftp,http}://ftp.gnu.org/gnu/glibc       \
               ftp://gcc.gnu.org/pub/glibc/releases     \
               ftp://gcc.gnu.org/pub/glibc/snapshots

    # C library addons
    for addon in "${addons_list[@]}"; do
        # NPTL addon is not to be downloaded, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_GetFile "glibc-${addon}-${CT_LIBC_VERSION}"      \
                   {ftp,http}://ftp.gnu.org/gnu/glibc       \
                   ftp://gcc.gnu.org/pub/glibc/releases     \
                   ftp://gcc.gnu.org/pub/glibc/snapshots
    done

    return 0
}

# Extract glibc
do_libc_extract() {
    local -a addons_list

    addons_list=($(do_libc_add_ons_list " "))

    CT_Extract "glibc-${CT_LIBC_VERSION}"

    CT_Pushd "${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}"
    CT_Patch nochdir "glibc" "${CT_LIBC_VERSION}"

    # C library addons
    for addon in "${addons_list[@]}"; do
        # NPTL addon is not to be extracted, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_Extract nochdir "glibc-${addon}-${CT_LIBC_VERSION}"

        CT_TestAndAbort "Error in add-on '${addon}': both short and long names in tarball" \
            -d "${addon}" -a -d "glibc-${addon}-${CT_LIBC_VERSION}"

        # Some addons have the 'long' name, while others have the
        # 'short' name, but patches are non-uniformly built with
        # either the 'long' or 'short' name, whatever the addons name
        # but we prefer the 'short' name and avoid duplicates.
        if [ -d "glibc-${addon}-${CT_LIBC_VERSION}" ]; then
            mv "glibc-${addon}-${CT_LIBC_VERSION}" "${addon}"
        fi

        ln -s "${addon}" "glibc-${addon}-${CT_LIBC_VERSION}"

        CT_Patch nochdir "glibc" "${addon}-${CT_LIBC_VERSION}"

        # Remove the long name since it can confuse configure scripts to run
        # the same source twice.
        rm "glibc-${addon}-${CT_LIBC_VERSION}"
    done

    # The configure files may be older than the configure.in files
    # if using a snapshot (or even some tarballs). Fake them being
    # up to date.
    sleep 2
    find . -type f -name configure -exec touch {} \; 2>&1 |CT_DoLog ALL

    CT_Popd

    return 0
}

# There is nothing to do for glibc check config
do_libc_check_config() {
    :
}
