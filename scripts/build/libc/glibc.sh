# This file adds functions to build glibc
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Add the definitions common to glibc and eglibc
#   do_libc_extract
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
        if ! CT_GetFile "glibc-${addon}-${CT_LIBC_VERSION}"     \
                        {ftp,http}://ftp.gnu.org/gnu/glibc      \
                        ftp://gcc.gnu.org/pub/glibc/releases    \
                        ftp://gcc.gnu.org/pub/glibc/snapshots
        then
            # Some add-ons are bundled with glibc, others are
            # bundled in their own tarball. Eg. NPTL is internal,
            # while LinuxThreads was external. Also, for old
            # versions of glibc, the libidn add-on was external,
            # but with version >=2.10, it is internal.
            CT_DoLog DEBUG "Addon '${addon}' could not be downloaded."
            CT_DoLog DEBUG "We'll see later if we can find it in the source tree"
        fi
    done

    return 0
}

# There is nothing to do for glibc check config
do_libc_check_config() {
    :
}
