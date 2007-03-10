# This script will download tarballs, extract them and patch the source.
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download tarballs in sequence. Once we have everything, start extracting
# and patching the tarballs.

#-----------------------------------------------------------------------------

_wget=`which wget || true`
_curl=`which curl || true`
#_svn=`which svn ||true`
#_cvs=`which cvs || true`

case "${_wget},${_curl}" in
    ,)  CT_Abort "Found neither curl nor wget. Please install one.";;
    ,*) CT_DoLog DEBUG "Using curl to retrieve tarballs"; CT_DoGetFile=CT_DoGetFileCurl;;
    *)  CT_DoLog DEBUG "Using wget to retrieve tarballs"; CT_DoGetFile=CT_DoGetFileWget;;
esac

CT_DoGetFileWget() {
    # Need to return true because it is legitimate not to find the tarball at
    # some of the provided URLs (think about snapshots, different layouts for
    # different gcc versions, etc...)
    # Some (very old!) FTP server might not support the passive mode, thus
    # retry without
    # With automated download as we are doing, it can be very dangerous to use
    # -c to continue the downloads. It's far better to simply overwrite the
    # destination file
    wget -nc --progress=dot:binary --tries=3 --passive-ftp "$1" || wget -nc --progress=dot:binary --tries=3 "$1" || true
}

CT_DoGetFileCurl() {
	# Note: comments about wget method are also valid here
	# Plus: no good progreess indicator is available with curl,
	#       so output is consigned to oblivion
	curl --ftp-pasv -O --retry 3 "$1" >/dev/null || curl -O --retry 3 "$1" >/dev/null || true
}

# For those wanting bleading edge, or to retrieve old uClibc snapshots
# Usage: CT_GetFileSVN basename url
#CT_DoGetFileSVN() {
#    local basename="$1"
#    local url="`echo \"$2\" |cut -d : -f 2-`"
#    local tmp_dir
#
#    CT_TestOrAbort "You don't have subversion" -n "${_svn}"
#    CT_MktempDir tmp_dir
#    CT_Pushd "${tmp_dir}"
#    svn export --force "${url}" "${basename}"
#    tar cfj "${CT_TARBALLS_DIR}/${basename}.tar.bz2" "${basename}"
#    CT_Popd
#    rm -rf "${tmp_dir}"
#}
#
#CT_DoGetFileCVS() {
#    :
#}

# Download the file from one of the URLs passed as argument
# Usage: CT_GetFile <filename> <url> [<url> ...]
CT_GetFile() {
    local got_it
    local ext
    local url
    local file="$1"
    shift

    # Do we already have it?
    ext=`CT_GetFileExtension "${file}"`
    if [ -n "${ext}" ]; then
        if [ "${CT_FORCE_DOWNLOAD}" = "y" ]; then
            rm -f "${CT_TARBALLS_DIR}/${file}${ext}"
        else
            return 0
        fi
    fi

    CT_DoLog EXTRA "Retrieving \"${file}\""
    CT_Pushd "${CT_TARBALLS_DIR}"
    # File not yet downloaded, try to get it
    got_it=0
    if [ "${got_it}" != "y" ]; then
        # We'd rather have a bzip2'ed tarball, then gzipped, and finally plain tar.
        for ext in .tar.bz2 .tar.gz .tgz .tar; do
            # Try all urls in turn
            for url in "$@"; do
                case "${url}" in
#                    svn://*)    CT_DoGetFileSVN "${file}" ${url}";;
#                    cvs://*)    CT_DoGetFileCVS "${file}" ${url}";;
                    *)  CT_DoLog EXTRA "Trying \"${url}/${file}${ext}\""
                        ${CT_DoGetFile} "${url}/${file}${ext}" 2>&1 |CT_DoLog DEBUG
                        ;;
                esac
                [ -f "${file}${ext}" ] && got_it=1 && break 2 || true
            done
        done
    fi
    CT_Popd

    CT_TestAndAbort "Could not download \"${file}\", and not present in \"${CT_TARBALLS_DIR}\"" ${got_it} -eq 0
}

#-----------------------------------------------------------------------------

# Extract a tarball and patch.
# Some tarballs need to be extracted in specific places. Eg.: glibc addons
# must be extracted in the glibc directory; uCLibc locales must be extracted
# in the extra/locale sub-directory of uClibc.
CT_ExtractAndPatch() {
    local file="$1"
    local base_file=`echo "${file}" |cut -d - -f 1`
    local ver_file=`echo "${file}" |cut -d - -f 2-`
    local official_patch_dir
    local custom_patch_dir
    local libc_addon
    local ext=`CT_GetFileExtension "${file}"`
    CT_TestAndAbort "\"${file}\" not found in \"${CT_TARBALLS_DIR}\"" -z "${ext}"
    local full_file="${CT_TARBALLS_DIR}/${file}${ext}"

    CT_Pushd "${CT_SRC_DIR}"

    # Add-ons need a little love, really.
    case "${file}" in
        glibc-[a-z]*-*)
            CT_TestAndAbort "Trying to extract the C-library addon/locales \"${file}\" when C-library not yet extracted" ! -d "${CT_LIBC_FILE}"
            cd "${CT_LIBC_FILE}"
            libc_addon=y
            [ -f ".${file}.extracted" ] && return 0
            touch ".${file}.extracted"
            ;;
        uClibc-locale-*)
            CT_TestAndAbort "Trying to extract the C-library addon/locales \"${file}\" when C-library not yet extracted" ! -d "${CT_LIBC_FILE}"
            cd "${CT_LIBC_FILE}/extra/locale"
            libc_addon=y
            [ -f ".${file}.extracted" ] && return 0
            touch ".${file}.extracted"
            ;;
    esac

    # If the directory exists, then consider extraction and patching done
    [ -d "${file}" ] && return 0

    CT_DoLog EXTRA "Extracting \"${file}\""
    case "${ext}" in
        .tar.bz2)     tar xvjf "${full_file}" |CT_DoLog DEBUG;;
        .tar.gz|.tgz) tar xvzf "${full_file}" |CT_DoLog DEBUG;;
        .tar)         tar xvf  "${full_file}" |CT_DoLog DEBUG;;
        *)            CT_Abort "Don't know how to handle \"${file}\": unknown extension" ;;
    esac

    # Snapshots might not have the version number in the extracted directory
    # name. This is also the case for some (old) packages, such as libfloat.
    # Overcome this issue by symlink'ing the directory.
    if [ ! -d "${file}" -a "${libc_addon}" != "y" ]; then
        case "${ext}" in
            .tar.bz2)     base=`tar tjf "${full_file}" |head -n 1 |cut -d / -f 1 || true`;;
            .tar.gz|.tgz) base=`tar tzf "${full_file}" |head -n 1 |cut -d / -f 1 || true`;;
            .tar)         base=`tar tf  "${full_file}" |head -n 1 |cut -d / -f 1 || true`;;
        esac
        CT_TestOrAbort "There was a problem when extracting \"${file}\"" -d "${base}" -o "${base}" != "${file}"
        ln -s "${base}" "${file}"
    fi

    # Kludge: outside this function, we wouldn't know if we had just extracted
    # a libc addon, or a plain package. Apply patches now.
    CT_DoLog EXTRA "Patching \"${file}\""

    # If libc addon, we're already in the correct place.
    [ -z "${libc_addon}" ] && cd "${file}"

    [ "${CUSTOM_PATCH_ONLY}" = "y" ] || official_patch_dir="${CT_TOP_DIR}/patches/${base_file}/${ver_file}"
    [ "${CT_CUSTOM_PATCH}" = "y" ] && custom_patch_dir="${CT_CUSTOM_PATCH_DIR}/${base_file}/${ver_file}"
    for patch_dir in "${official_patch_dir}" "${custom_patch_dir}"; do
        if [ -n "${patch_dir}" -a -d "${patch_dir}" ]; then
            for p in "${patch_dir}"/*.patch; do
                if [ -f "${p}" ]; then
                    CT_DoLog DEBUG "Applying patch \"${p}\""
                    patch -g0 -F1 -p1 -f <"${p}" |CT_DoLog DEBUG
                    CT_TestAndAbort "Failed while applying patch file \"${p}\"" ${PIPESTATUS[0]} -ne 0
                fi
            done
        fi
    done

    CT_Popd
}

#-----------------------------------------------------------------------------

# Get the file name extension of a component
# Usage: CT_GetFileExtension <component-version>
# If found, echoes the extension to stdout
# If not found, echoes nothing on stdout.
CT_GetFileExtension() {
    local ext
    local file="$1"
    local got_it=1

    CT_Pushd "${CT_TARBALLS_DIR}"
    for ext in .tar.gz .tar.bz2 .tgz .tar; do
        if [ -f "${file}${ext}" ]; then
            echo "${ext}"
            got_it=0
            break
        fi
    done
    CT_Popd

    return 0
}

#-----------------------------------------------------------------------------

# Create needed directories, remove old ones
mkdir -p "${CT_TARBALLS_DIR}"
if [ "${CT_FORCE_EXTRACT}" = "y" -a -d "${CT_SRC_DIR}" ]; then
    mv "${CT_SRC_DIR}" "${CT_SRC_DIR}.$$"
    nohup rm -rf "${CT_SRC_DIR}.$$" >/dev/null 2>&1 &
fi
mkdir -p "${CT_SRC_DIR}"

# Make all path absolute, it so much easier!
# Now we have had the directories created, we even will get rid of embedded .. in paths:
CT_SRC_DIR="`CT_MakeAbsolutePath \"${CT_SRC_DIR}\"`"
CT_TARBALLS_DIR="`CT_MakeAbsolutePath \"${CT_TARBALLS_DIR}\"`"

# Prepare the addons list to be parsable:
addons_list="`echo \"${CT_LIBC_ADDONS_LIST}\" |sed -r -e 's/,/ /g; s/ $//g;'`"

if [ "${CT_NO_DOWNLOAD}" != "y" ]; then
    CT_DoStep INFO "Retrieving needed toolchain components' tarballs"

    # Kernel: for now, I don't care about cygwin.
    CT_GetFile "${CT_KERNEL_FILE}"                                  \
               ftp://ftp.kernel.org/pub/linux/kernel/v2.6           \
               ftp://ftp.kernel.org/pub/linux/kernel/v2.4           \
               ftp://ftp.kernel.org/pub/linux/kernel/v2.2           \
               ftp://ftp.kernel.org/pub/linux/kernel/v2.6/testing   \
               http://ep09.pld-linux.org/~mmazur/linux-libc-headers

    # binutils
    CT_GetFile "${CT_BINUTILS_FILE}"                            \
               ftp://ftp.gnu.org/gnu/binutils                   \
               ftp://ftp.kernel.org/pub/linux/devel/binutils

    # Core and final gcc
    # Ah! gcc folks are kind of 'different': they store the tarballs in
    # subdirectories of the same name! That's because gcc is such /crap/ that
    # it is such /big/ that it needs being splitted for distribution! Sad. :-(
    # Arrgghh! Some of those versions does not follow this convention:
    # gcc-3.3.3 lives in releases/gcc-3.3.3, while gcc-2.95.* isn't in a
    # subdirectory! You bastard!
    CT_GetFile "${CT_CC_CORE_FILE}"                                    \
               ftp://ftp.gnu.org/gnu/gcc/${CT_CC_CORE_FILE}            \
               ftp://ftp.gnu.org/gnu/gcc/releases/${CT_CC_CORE_FILE}   \
               ftp://ftp.gnu.org/gnu/gcc
    CT_GetFile "${CT_CC_FILE}"                                  \
               ftp://ftp.gnu.org/gnu/gcc/${CT_CC_FILE}          \
               ftp://ftp.gnu.org/gnu/gcc/releases/${CT_CC_FILE} \
               ftp://ftp.gnu.org/gnu/gcc

    # C library
    case "${CT_LIBC}" in
        glibc)
            # Ah! Not all GNU folks seem stupid. All glibc releases are in the same
            # directory. Good. Alas, there is no snapshot there. I'll deal with them
            # later on... :-/
            libc_src="ftp://ftp.gnu.org/gnu/glibc"
            ;;
        uClibc)
            # For uClibc, we have almost every thing: releases, and snapshots
            # for the last month or so. We'll have to deal with svn revisions
            # later...
            libc_src="http://www.uclibc.org/downloads
                      http://www.uclibc.org/downloads/snapshots
                      http://www.uclibc.org/downloads/old-releases"
            ;;
    esac
    CT_GetFile "${CT_LIBC_FILE}" ${libc_src}

    # C library addons
    addons_list=`echo "${CT_LIBC_ADDONS}" |sed -r -e 's/,/ /g; s/ $//g;'`
    for addon in ${addons_list}; do
        CT_GetFile "${CT_LIBC}-${addon}-${CT_LIBC_VERSION}" ${libc_src}
    done
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && CT_GetFile "${CT_LIBC}-ports-${CT_LIBC_VERSION}" ${libc_src}
    [ "${CT_LIBC_UCLIBC_LOCALES}" = "y" ] && CT_GetFile "uClibc-locale-030818" ${libc_src}

    # libfloat if asked for
    if [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ]; then
        lib_float_url="ftp://ftp.de.debian.org/debian/pool/main/libf/libfloat/"

        # Please note: because the file we download, and the file we store on the
        # file system don't have the same name, CT_GetFile will always try to
        # download the file over and over.
        # To avoid this, we check that the file we want already exists in the
        # tarball directory first. This is an ugly hack that overrides the standard
        # CT_GetFile behavior... Sight...
        ext=`CT_GetFileExtension "${CT_LIBFLOAT_FILE}"`
        if [ -z "${ext}" ]; then
            CT_GetFile libfloat_990616.orig "${lib_float_url}"
            ext=`CT_GetFileExtension "libfloat_990616.orig"`
            # Hack: remove the .orig extension, and change _ to -
            mv -v "${CT_TARBALLS_DIR}/libfloat_990616.orig${ext}" \
                  "${CT_TARBALLS_DIR}/libfloat-990616${ext}"      2>&1 |CT_DoLog DEBUG
        fi
    fi
    
    CT_EndStep
fi # CT_NO_DOWNLOAD

if [ "${CT_ONLY_DOWNLOAD}" != "y" ]; then
    CT_DoStep INFO "Extracting and patching toolchain components"

    CT_ExtractAndPatch "${CT_KERNEL_FILE}"
    CT_ExtractAndPatch "${CT_BINUTILS_FILE}"
    CT_ExtractAndPatch "${CT_CC_CORE_FILE}"
    CT_ExtractAndPatch "${CT_CC_FILE}"
    CT_ExtractAndPatch "${CT_LIBC_FILE}"
    for addon in ${addons_list}; do
        CT_ExtractAndPatch "${CT_LIBC}-${addon}-${CT_LIBC_VERSION}"
    done
    [ "${CT_LIBC_GLIBC_USE_PORTS}" = "y" ] && CT_ExtractAndPatch "${CT_LIBC}-ports-${CT_LIBC_VERSION}"
    [ "${CT_LIBC_UCLIBC_LOCALES}" = "y" ] && CT_ExtractAndPatch "uClibc-locale-030818"

    [ "${CT_ARCH_FLOAT_SW_LIBFLOAT}" = "y" ] && CT_ExtractAndPatch "${CT_LIBFLOAT_FILE}"

    CT_EndStep
fi
