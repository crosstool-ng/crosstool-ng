#!/bin/sh

repos="$1"
pdir="$2"
if [ -z "${repos}" -o ! -d "${repos}" -o -z "${pdir}" -o ! -d "${pdir}" ];then
    printf "Usage: ${0##*/} <repos_dir> <patch_dir>\n"
    exit 1
fi

pdir="$( cd "${pdir}"; pwd)"
version="$( echo "${pdir}" |sed -r -e 's,.*/([^/]+)/*$,\1,' )"
branch="${version%.*}"
n=$( ls -1 "${pdir}" 2>/dev/null |wc -l )

r1="$( hg -R "${repos}" log -b "${branch}"  \
       |awk '
            $1=="changeset:" {
                prev=rev;
                split($2,a,":");
                rev=a[1];
            }
            $0~/^summary:[[:space:]]+'"${branch}: (bump|update) version to ${version}\+hg"'$/ {
                printf( "%d\n", prev );
            }
            '
     )"

i=0
hg -R "${repos}" log -b "${branch}" -r "${r1}:tip" --template '{rev}\n'    \
|while read rev; do
    p="$( printf "%03d" ${i} )"
    i=$((i+1))
    if [ $( ls -1 "${pdir}/${p}-"*.patch 2>/dev/null |wc -l ) -ne 0 ]; then
        continue
    fi
    plog=$( hg -R "${repos}" log -r ${rev} --template '{desc|firstline}\n'  \
            |sed -r -e 's,[^[:alnum:]],_,g; s/_+/_/g;'                      \
          )
    pname="${p}-${plog}.patch"
    printf "Revision '%d' --> '%s'\n" ${rev} "${pname}"
    hg -R "${repos}" diff -c ${rev} --color=never >"${pdir}/${pname}"
    pdate="$( hg -R "${repos}" log -r ${rev} --template '{date|isodate}\n' )"
    touch -d "${pdate}" "${pdir}/${pname}"
done
