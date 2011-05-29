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
        # NPTL addon is not to be downloaded, in any case
        [ "${addon}" = "nptl" ] && continue || true
        CT_GetFile "glibc-${addon}-${CT_LIBC_VERSION}"      \
                   {ftp,http}://ftp.gnu.org/gnu/glibc       \
                   ftp://gcc.gnu.org/pub/glibc/releases     \
                   ftp://gcc.gnu.org/pub/glibc/snapshots
    done

    return 0
}

# There is nothing to do for glibc check config
do_libc_check_config() {
    :
}
