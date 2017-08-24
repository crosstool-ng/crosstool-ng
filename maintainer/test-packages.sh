#!/bin/bash

selected=

usage()
{
    cat <<EOF
$0 -- Test packages in crosstool-NG

Verifies that the release tarballs can be downloaded for the packages
available in crosstoo-NG and check that the patches apply cleanly.
Requires crosstool-NG to be configured and built prior to running.

Options:
    --help, -?
        Display this help message.

    --download, -d
        Download all packages to the default directory (\$HOME/src).

    --apply-patches, -a
        Implies -d. Unpack and apply the bundled patches.

    --verify-urls, -u
        Check *all* the download URLs for accessibility, without
        actually downloading anything.

    --select MASK, -s MASK
        Specify the package to operate upon. MASK can be either package
        name ("-s foo"), or package name + version ("-s foo-1.1").

EOF
}

while [ -n "${1}" ]; do
    case "${1}" in
    --download|-d)
        download_pkgs=y
        ;;
    --verify-urls|-u)
        verify_urls=y
        ;;
    --apply-patches|-a)
        apply_patches=y
        download_pkgs=y
        ;;
    --select|-s)
        shift
        [ -n "${1}" ] || { echo "argument required for --select" >&2; exit 1; }
        selected="${1}"
        ;;
    --help|-?)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option ${1}" >&2
        exit 1
        ;;
    esac
    shift
done

CT_LIB_DIR=`pwd`
CT_TOP_DIR=`pwd`
CT_TARBALLS_DIR=`pwd`/temp.tarballs
CT_COMMON_SRC_DIR=`pwd`/temp.src
CT_SRC_DIR=`pwd`/temp.src
CT_LOG_LEVEL_MAX=EXTRA
mkdir -p ${CT_TARBALLS_DIR}

# Does not matter, just to make the scripts load
CT_ARCH=arm
CT_KERNEL=bare-metal
CT_BINUTILS=binutils
CT_LIBC=none
CT_CC=gcc

. paths.sh
. scripts/functions

rm -f build.log
CT_LogEnable

check_pkg_urls()
{
    local e m mh url

    for e in ${archive_formats}; do
        local -A mirror_status=( )

        CT_DoStep EXTRA "Looking for ${archive_filename}${e}"
        for m in ${mirrors}; do
            url="${m}/${archive_filename}${e}"
            case "${url}" in
            # WGET always returns success for FTP URLs in spider mode :(
            ftp://*) CT_DoLog DEBUG "Skipping '${url}': FTP not supported"; continue;;
            esac
            mh="${url#*://}"
            mh="${mh%%[:/]*}"
            if [ -n "${mirror_status[${mh}]}" ]; then
                CT_DoLog DEBUG "Skipping '${url}': already found on this host at '${mirror_status[${mh}]}'"
                continue
            fi
            if CT_DoExecLog ALL wget --spider "${url}"; then
                mirror_status[${mh}]="${url}"
            else
                mirror_status[${mh}]=
            fi
        done
        for mh in "${!mirror_status[@]}"; do
            if [ -n "${mirror_status[${mh}]}" ]; then
                CT_DoLog EXTRA "OK   ${mh} [${archive_filename}${e}]"
            else
                CT_DoLog ERROR "FAIL ${mh} [${archive_filename}${e}]"
            fi
        done
        CT_EndStep
    done
}

run_pkgversion()
{
    while [ -n "${1}" ]; do
        eval "local ${1}"
        shift
    done

    if [ -n "${selected}" ]; then
        case "${selected}" in
        ${pkg_name}|${pkg_name}-${ver})
            ;;
        *)
            return
            ;;
        esac
    fi

    CT_DoStep INFO "Handling ${pkg_name}-${ver}"

    # Create a temporary configuration head file
    cat >temp.in <<EOF
config OBSOLETE
    def_bool y

config EXPERIMENTAL
    def_bool y

config CONFIGURE_has_wget
    def_bool y

config CONFIGURE_has_curl
    def_bool y

config ${versionlocked}_V_${kcfg}
    def_bool y

source "config/global/paths.in"
source "config/global/download.in"
source "config/global/extract.in"
source "config/versions/${master}.in"
EOF

    cat >temp.defconfig <<EOF
CT_${masterpfx}_USE_${originpfx}=y
CT_${pfx}_SRC_RELEASE=y
CT_${pfx}_V_${kcfg}=y
CT_SAVE_TARBALLS=y
EOF

    ./kconfig/conf --defconfig=temp.defconfig temp.in >/dev/null

    CT_LoadConfig
    rm -f .config .config.old temp.defconfig temp.in
    if [ -n "${verify_urls}" ]; then
        CT_DoLog EXTRA "Verifying URLs for ${pkg_name}-${ver}"
        CT_PackageRun "${masterpfx}" check_pkg_urls
    fi
    if [ -n "${download_pkgs}" ]; then
        CT_DoLog EXTRA "Downloading ${pkg_name}-${ver}"
        CT_Fetch "${masterpfx}"
    fi
    if [ -n "${apply_patches}" ]; then
        rm -rf ${CT_COMMON_SRC_DIR}
        mkdir -p ${CT_COMMON_SRC_DIR}
        CT_ExtractPatch "${masterpfx}"
    fi

    CT_EndStep
}

. maintainer/package-versions

rm -rf ${CT_TARBALLS_DIR} ${CT_COMMON_SRC_DIR}
