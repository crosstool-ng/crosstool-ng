#!/bin/sh
# Yes, this intends to be a true POSIX script file.
set -e

myname="$0"

# Parse the tools' paths configuration
. "paths.mk"

doUsage() {
  cat <<_EOF_
Usage: ${myname} <dir> <base> <inc> [sed_re]
    Will renumber all patches found in 'dir', starting at 'base', and with
    an increment of 'inc'.
    If 'sed_re' is given, it is interpreted as a valid sed expression, and
    it will be applied to the patch name.
    If the environment variable FAKE is set to 'y', then the command will
    only be printed, and not executed (so you can check beforehand).
    Eg.:
      patch-renumber.sh patches/gcc/4.3.1 100 10
      patch-renumber.sh patches/gcc/4.2.4 100 10 's/(all[_-])*(gcc[-_])*//;'
_EOF_
}

[ $# -lt 3 -o $# -gt 4 ] && { doUsage; exit 1; }
[ -d "${1}" ] || { doUsage; exit 1; }

dir="${1}"
cpt="${2}"
inc="${3}"
sed_re="${4}"

case "$(LC_ALL=C hg id "${dir}" 2>/dev/null)" in
    "") CMD="";;
    *)  CMD="hg";;
esac

if [ "${FAKE}" = "y" ]; then
    CMD="echo ${CMD}"
fi

for p in "${dir}"/*.patch*; do
    [ -e "${p}" ] || { echo "No such file '${p}'"; exit 1; }
    newname="$(printf "%03d-%s"                                     \
                      "${cpt}"                                      \
                      "$( basename "${p}"                           \
                          |"${sed}" -r -e 's/^[[:digit:]]+[-_]//'   \
                                       -e "${sed_re}"               \
                        )"                                          \
              )"
    [ "${p}" = "${dir}/${newname}" ] || ${CMD} mv -v "${p}" "${dir}/${newname}"
    cpt=$((cpt+inc))
done
