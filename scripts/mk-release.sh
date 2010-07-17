#!/bin/bash
#set -x

export LC_ALL=C

my_name="$( basename "${0}" )"

usage() {
    cat <<-_EOF_
		Usage:
		    ${my_name} <repos_dir> <M.m.p>
	_EOF_
}

repos="${1}"
version="${2}"

[ -n "${repos}"   ] || { usage; exit 1; }
[ -d "${repos}"   ] || { printf "${my_name}: ${repos}: no such file or directory\n"; exit 1; }
[ -n "${version}" ] || { usage; exit 1; }

gen_bound_revs() {
    r1=$( hg log    \
          |awk 'BEGIN {
                  found=0;
                }
                $1=="'"${label}"':" {
                  split($2,a,":"); rev=a[1];
                }
                $0~/^summary:[[:space:]]*[[:digit:]]+\.[[:digit:]]+: '"${msg}"'/ \
                && found==0 {
                  printf( "%d\n", rev ); found=1;
                }'
        )

    r2=$( hg log -b "${branch}" \
          |awk '$1=="changeset:" {
                  split($2,a,":");
                  printf( "%d\n", a[1] );
                  nextfile;
                }'
        )

    r1_log=$((r1+log_offset))
    if [ ${#r1_log} -gt ${#r2} ]; then
        rev_w=${#r1_log}
    else
        rev_w=${#r2}
    fi
}

print_intro_mail() {
    cat <<-_EOF_
		Hello all!
		
		I'm pleased to announce the release of crosstool-NG ${version}!
		
		As usual, there has been quite a number of improvements, new features,
		and bug fixes all around. The most notable changes are listed below:
		
		YEM:
		YEM: PUT YOUR MESSAGE HERE
		YEM:
		
		This marks the beginning of the ${ver_M}.${ver_m} maintenance branch, and the end of
		the previous maintenance branch. As always, comments and suggestions
		are most welcome!
		
		The release can be found at the following URLs:
		Changelog: http://ymorin.is-a-geek.org/download/crosstool-ng/crosstool-ng-${version}.changelog
		Tarball:   http://ymorin.is-a-geek.org/download/crosstool-ng/crosstool-ng-${version}.tar.bz2
		Patches:   http://ymorin.is-a-geek.org/download/crosstool-ng/01-fixes/${version}/
		
		As a reminder, the home for crosstool-NG is:
		http://ymorin.is-a-geek.org/projects/crosstool
		
		Crosstool-NG also has a Freshmeat page:
		http://freshmeat.net/projects/crosstool-ng
	_EOF_
}

print_intro_changelog_full_release() {
    cat <<-_EOF_
		crosstool-NG ${version} -- ${date}
		
		This is a feature-release. Significant changes are:
		
		YEM:
		YEM: PUT YOUR MESSAGE HERE
		YEM:
	_EOF_
}

print_intro_changelog_bug_fix() {
    cat <<-_EOF_
		crosstool-NG ${version} -- ${date}
		
		This is a bug-fix-only release.
	_EOF_
}

print_author_stats() {
    printf "\nMany thanks to the people who contributed to this release:\n\n"
    prev_author=""
    template='{author|person}\n'
    hg log -b "${branch}" -r "${r1_log}:${r2}"                  \
           --template "${template}"                             \
    |sed -r -e 's/"//g;'                                        \
    |awk -F '' '{
                  nb[$0]++;
                }
                END {
                  for( author in nb ) {
                    printf( "   %4d  %s\n", nb[author], author );
                  }
                }'                                              \
    |sort -s -k1nr -k2
}

print_author_shortlog() {
    printf "\nHere is the per-author shortlog:\n"
    prev_author=""
    template='{author|person}|{rev}|{branches}|{desc|firstline}\n'
    hg log -b "${branch}" -r "${r1_log}:${r2}"              \
           --template "${template}"                         \
    |awk -F '' '{
                  n=split( $0,a,"|" );
                  printf( "%s", gensub("\"","","g",a[1]) );
                  printf( "|%0*d", '${rev_w}', a[2] );
                  for(i=3;i<=n;i++) {
                    printf( "|%s", a[i] );
                  }
                  printf( "\n" );
                }'                                          \
    |sort                                                   \
    |while read line; do
        author="$( echo "${line}" |cut -d \| -f 1 )"
        rev="$( echo "${line}" |cut -d \| -f 2 )"
        br="$( echo "${line}" |cut -d \| -f 3 )"
        desc="$( echo "${line}" |cut -d \| -f 4- )"

        case "${br}" in
            ${branch})  ;;
            [0-9]*.*)    continue;;
            *) ;;
        esac

        case "${desc}" in
            Merge.)                 continue;;
            *": close "*" branch"*) continue;;
#           *\(merged\))            continue;;
        esac

        author="$( echo "${author}" |sed -r -e 's/"//g;' )"

        if [ ! "${prev_author}" = "${author}" ]; then
            printf "\n"
            printf "    ${author}:\n"
            prev_author="${author}"
        fi
        rev="$( echo "${rev}" |sed -r -e 's/^0*//;' )"

        printf "%s\n" "${desc}"     \
        |fmt -w 65                  \
        |(first=1; while read l; do
            if [ -n "${first}" ]; then
                printf "        [%*d] %s\n" ${rev_w} ${rev} "${l}"
                first=
            else
                printf "         %*.*s  %s\n" ${rev_w} ${rev_w} '' "${l}"
            fi
        done)
    done
}

print_diffstat() {
    printf "\nThe diffstat follows:\n\n"
    hg diff -r "${r1}:${r2}" --color=never  \
    |diffstat -r 2 -p 1 -w 10               \
    |tail -n 1                              \
    |sed -r -e 's/^ */    /;'

    hg diff -r "${r1}:${r2}" --color=never  \
    |diffstat -f 1 -r 2 -p 1 -w 10          \
    |head -n -1                             \
    |while read file line; do
        if [ ${#file} -gt 57 ]; then
            file="$( echo "${file}" |sed -r -e 's/^(.{,24}).*(.{28})$/\1.....\2/;' )"
        fi
        printf "    %-57s %s\n" "${file}" "${line}"
    done
}

print_short_diffstat() {
    printf "\nThe short diffstat follows:\n\n"

    eval total=$(( $(
        hg diff -r "${r1}:${r2}" --color=never "${i}"                               \
        |diffstat -r 2 -p 1 -w 10                                                   \
        |tail -n 1                                                                  \
        |sed -r -e 's/^[[:space:]]*[[:digit:]]+ files? changed(,[[:space:]]+|$)//;' \
                -e 's/([[:digit:]]+)[^-\+]+\((-|\+)\)/\1/g;'                        \
                -e 's/,//g; s/ /+/; s/^$/0/;'
    ) ))
    printf "    %-24.24s %5d(+/-)\n" "Total" ${total}
    others=${total}

    { for i in              \
        kconfig/            \
        patches/            \
        config/*/           \
        scripts/build/*/    \
        samples/            \
        ; do
        eval val=$(( $(
            hg diff -r "${r1}:${r2}" --color=never "${i}"                               \
            |diffstat -r 2 -p 1 -w 10                                                   \
            |tail -n 1                                                                  \
            |sed -r -e 's/^[[:space:]]*[[:digit:]]+ files? changed(,[[:space:]]+|$)//;' \
                    -e 's/([[:digit:]]+)[^-\+]+\((-|\+)\)/\1/g;'                        \
                    -e 's/,//g; s/ /+/; s/^$/0/;'
        ) ))
        if [ ${val} -gt $((total/100)) ]; then
            printf "%d %s\n" $(((1000*val)/total)) "${i}"
            others=$((others-val))
        fi
    done; printf "%d Others\n" $(((1000*others)/total)); }  \
    |sort -nr                                               \
    |{ while read v i; do
        if [ "${i}" = "Others" ]; then
            others=${v}
        else
            printf "    %-24.24s %3d.%d%%\n" "${i}" $((v/10)) $((v%10))
        fi
       done; printf "    %-24.24s %3d.%d%%\n" "Others" $((others/10)) $((others%10)); }
}

ver_M="$( printf "${version}" |cut -d . -f 1 )"
ver_m="$( printf "${version}" |cut -d . -f 2 )"
ver_p="$( printf "${version}" |cut -d . -f 3 )"

prefix="$(pwd)/crosstool-ng-${version}"
pushd "${repos}" >/dev/null 2>&1

printf "Checking for existing tag: "
if hg tags |grep -E '^'"crosstool-ng-${version}"'\>' >/dev/null; then
    printf "already tagged\n"
    exit 1
fi
printf "no\n"

if [ ${ver_p} -eq 0 ]; then
    print_mail="yes"
    print_intro_changelog="print_intro_changelog_full_release"
    label="parent"
    msg="create maintenance branch, (update|bump) version to [[:digit:]]+"'\'".[[:digit:]]+"'\'".0"'$'
    branch="default"
    log_offset=0
else
    print_mail="no"
    print_intro_changelog="print_intro_changelog_bug_fix"
    label="changeset"
    msg="(update|bump) version to ${ver_M}"'\'".${ver_m}"'\'".$((ver_p-1))"'\+hg$'
    branch="${ver_M}.${ver_m}"
    log_offset=1
fi

printf "Computing boundary revisions:"
gen_bound_revs
printf " %d:%d\n" ${r1} ${r2}

printf "Tagging release:"
hg up "${branch}" >/dev/null
if [ ${ver_p} -eq 0 ]; then
    printf " update version"
    hg branch "${ver_M}.${ver_m}" >/dev/null
    echo "${version}" >".version"
    hg ci -m "${ver_M}.${ver_m}: create maintenance branch, update version to ${version}"
else
    printf " update version"
    echo "${version}" >".version"
    hg ci -m "${ver_M}.${ver_m}: update version to ${version}"
fi

printf ", tag"
hg tag -m "Tagging release ${version}" crosstool-ng-${version}

printf ", update version"
echo "${version}+hg" >".version"
hg ci -m "${ver_M}.${ver_m}: update version to ${version}+hg"

printf ", date"
date="$( hg log -r crosstool-ng-${version} --template '{date|isodate}\n'    \
         |sed -r -e 's/-|://g; s/ /./; s/ //;'                              \
       )"
printf ", done.\n"

if [ ${ver_p} -eq 0 ]; then
    printf "Generating release mail:"
    printf " intro"
    print_intro_mail        > "${prefix}.mail"
    printf ", stats"
    print_author_stats      >>"${prefix}.mail"
    printf ", shortlog"
    print_author_shortlog   >>"${prefix}.mail"
    printf ", diffstat"
    print_short_diffstat    >>"${prefix}.mail"
    printf ", done.\n"
fi

printf "Generating release changelog:"
printf " intro"
${print_intro_changelog}    > "${prefix}.changelog"
printf ", stats"
print_author_stats          >>"${prefix}.changelog"
printf ", shortlog"
print_author_shortlog       >>"${prefix}.changelog"
printf ", diffstat"
print_diffstat              >>"${prefix}.changelog"
printf ", done.\n"

popd >/dev/null 2>&1

printf "Creating tarball:"
prefix="crosstool-ng-${version}"
printf " archive"
hg archive --cwd "${repos}" -r "${prefix}" -X '.hg*' "$(pwd)/${prefix}.tar.bz2"
date="$( hg log -R "${repos}" -r "${prefix}" --template '{date|rfc822date}\n' )"
printf ", sum"
for s in md5 sha1 sha512; do
    ${s}sum "${prefix}.tar.bz2" >"${prefix}.tar.bz2.${s}"
done
printf ", touch"
touch -d "${date}" "${prefix}"*
printf ", done.\n"

if [ ${ver_p} -eq 0 ]; then
    printf "\nAn editor will be launched for you to edit the mail.\n"
    read -p "Press enter when ready..." foo
    cp "${prefix}.mail"{,.orig}
    vi "${prefix}.mail"
    diff -du -U 1 "${prefix}.mail"{.orig,} |patch -p0 "${prefix}.changelog" >/dev/null
    rm -f "${prefix}".{mail,changelog}.orig
fi

printf "\nAn editor will be launched for you to review the changelog.\n"
read -p "Press enter when ready..." foo
vi "${prefix}.changelog"

printf "\nNow, you can push the changes with:   hg push -R '${repos}'\n"
