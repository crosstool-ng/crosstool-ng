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
        # Never ever try to download these add-ons,
        # they've always been internal
        case "${addon}" in
            nptl)   continue;;
        esac

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

# Extract the files required for the libc locales
# Nothing to do
do_libc_locales_extract() {
    :
}

# Build and install the libc locales
do_libc_locales() {
    local src_dir="${CT_SRC_DIR}/glibc-${CT_LIBC_VERSION}"
    local -a extra_config
    local glibc_cflags

    mkdir -p "${CT_BUILD_DIR}/build-localedef"
    cd "${CT_BUILD_DIR}/build-localedef"

    CT_DoLog EXTRA "Configuring C library localedef"

    if [ "${CT_LIBC_EGLIBC_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    CT_DoLog DEBUG "Extra config args passed: '${extra_config[*]}'"

    glibc_cflags="-O2 -fno-stack-protector"
    case "${CT_LIBC_ENABLE_FORTIFIED_BUILD}" in
        y)  ;;
        *)  glibc_cflags+=" -U_FORTIFY_SOURCE";;
    esac

    # ./configure is misled by our tools override wrapper for bash
    # so just tell it where the real bash is _on_the_target_!
    # Notes:
    # - ${ac_cv_path_BASH_SHELL} is only used to set BASH_SHELL
    # - ${BASH_SHELL}            is only used to set BASH
    # - ${BASH}                  is only used to set the shebang
    #                            in two scripts to run on the target
    # So we can safely bypass bash detection at compile time.
    # Should this change in a future eglibc release, we'd better
    # directly mangle the generated scripts _after_ they get built,
    # or even after they get installed... eglibc is such a sucker...
    echo "ac_cv_path_BASH_SHELL=/bin/bash" >>config.cache

    # Configure with --prefix the way we want it on the target...

    CT_DoExecLog CFG                                                \
    CFLAGS="${glibc_cflags}"                                        \
    "${src_dir}/configure"                                          \
        --prefix=/usr                                               \
        --cache-file="$(pwd)/config.cache"                          \
        --without-cvs                                               \
        --disable-profile                                           \
        --without-gd                                                \
        --disable-debug                                             \
        "${extra_config[@]}"

    CT_DoLog EXTRA "Building C library localedef"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    # The target's endianness and uint32_t alignment should be passed as options
    # to localedef, but glibc's localedef does not support these options, which
    # means that the locale files generated here will be suitable for the target
    # only if it has the same endianness and uint32_t alignment as the host's.

    CT_DoLog EXTRA "Installing C library locales"
    CT_DoExecLog ALL make ${JOBSFLAGS}                              \
                          install_root="${CT_SYSROOT_DIR}"          \
                          localedata/install-locales
}
