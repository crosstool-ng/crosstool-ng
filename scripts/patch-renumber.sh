#!/bin/sh
# Yes, this intends to be a true POSIX script file.
set -e

myname="$0"

# Parse the tools' paths configuration
. "paths.mk"

doUsage() {
  cat <<_EOF_
Usage: ${myname} <dir> <base> <inc>
    Will renumber all patches found in <dir>, starting at <base>, and with
    an increment of <inc>
    Eg.: patch-renumber patches/gcc/4.3.1 100 10
_EOF_
}

[ $# -eq 3 ] || { doUsage; exit 1; }
[ -d "${1}" ] || { doUsage; exit 1; }

dir="${1}"
cpt="${2}"
inc="${3}"

case "$(LC_ALL=C hg id "${dir}" 2>/dev/null)" in
    "") CMD="mv -v";;
    *)  CMD="hg mv";;
esac

for p in "${dir}"/*.patch; do
    [ -e "${p}" ] || { echo "No such file '${p}'"; exit 1; }
    newname="$(printf "%03d-%s"                                 \
                      "${cpt}"                                  \
                      "$(basename "${p}"                        \
                        |"${sed}" -r -e 's/^[[:digit:]]+[-_]//' \
                       )"                                       \
              )"
    [ "${p}" = "${dir}/${newname}" ] || ${CMD} "${p}" "${dir}/${newname}"
    cpt=$((cpt+inc))
done
