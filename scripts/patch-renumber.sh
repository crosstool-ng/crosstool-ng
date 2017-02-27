#!/bin/sh
# Yes, this intends to be a true POSIX script file.
set -e

myname="$0"

# Parse the tools' paths configuration
# It is expected that this script is only to be run from the
# source directory of crosstool-NG, so it is trivial to find
# paths.sh (we can't use  ". paths.sh", as POSIX states that
# $PATH should be searched for, and $PATH most probably doe
# not include "."), hence the "./".
. "./paths.sh"

doUsage() {
  cat <<_EOF_
Usage: ${myname} <src_dir> <dst_dir> <base> <inc> [sed_re]
    Renumbers all patches found in 'src_dir', starting at 'base', with an
    increment of 'inc', and puts the renumbered patches in 'dst_dir'.
    Leading digits are replaced with the new indexes, and a subsequent '_'
    is replaced with a '-'.
    If 'sed_re' is given, it is interpreted as a valid sed expression, and
    is be applied to the patch name.
    If the environment variable FAKE is set to 'y', then nothing gets done,
    the command to run is only be printed, and not executed (so you can
    check beforehand).
    'dst_dir' must not yet exist.
    Eg.:
      patch-renumber.sh patches/gcc/4.2.3 patches/gcc/4.2.4 100 10
      patch-renumber.sh /some/dir/my-patches patches/gcc/4.3.1 100 10 's/(all[_-])*(gcc[-_])*//;'
_EOF_
}

[ $# -lt 4 -o $# -gt 5 ] && { doUsage; exit 1; }

src="${1}"
dst="${2}"
cpt="${3}"
inc="${4}"
sed_re="${5}"
if [ ! -d "${src}" ]; then
    printf "%s: '%s': not a directory\n" "${myname}" "${src}"
    exit 1
fi
if [ -d "${dst}" ]; then
    printf "%s: '%s': directory already exists\n" "${myname}" "${dst}"
    exit 1
fi

Q=
if [ -n "${FAKE}" ]; then
    printf "%s: won't do anything: FAKE='%s'\n" "${myname}" "${FAKE}"
    Q="echo"
fi

${Q} mkdir -pv "${dst}"
for p in "${src}/"*.patch*; do
    [ -e "${p}" ] || { echo "No such file '${p}'"; exit 1; }
    newname="$(printf "%03d-%s"                                     \
                      "${cpt}"                                      \
                      "$( basename "${p}"                           \
                          |"${sed}" -r -e 's/^[[:digit:]]+[-_]//'   \
                                       -e "${sed_re}"               \
                        )"                                          \
              )"
    ${Q} cp -v "${p}" "${dst}/${newname}"
    cpt=$((cpt+inc))
done
