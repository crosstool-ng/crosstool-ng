#!/bin/sh

# Get our required options
base="$1"
src="$2"
dst="$3"
shift 3

# The remainder is for diff
diff="$@"

# This function checks that the files listed in the file in "$1"
# do exist, at the given depth-stripping level (aka diff -p#)
do_check_files_at_depth() {
  local flist="$1"
  local depth="$2"
  local ok=0  # 0: OK,  !0: KO

  exec 6<&0
  exec 7<"${flist}"

  while read -u7 f; do
    f="$( echo "${f}" |sed -r -e "s:^([^/]+/){${depth}}::;" )"
    [ -f "${f}" ] || ok=1
  done

  exec 7<&-
  exec <&6

  return ${ok}
}

mkdir -p "${dst}"
base="${base%%/}"
src="$( cd "${src}"; pwd )"
dst="$( cd "${dst}"; pwd )"

# Iterate through patches
for p in "${src}/"*.patch; do
  pname="$( basename "${p}" )"

  printf "Handling patch '${pname}'...\n"

  printf "  creating reference..."
  cp -a "${base}" "${base}.orig"
  printf " done\n"

  printf "  retrieving patch comment..."
  comment="$( awk '
BEGIN { mark=0; }
$0~/^diff --/ { nextfile; }
$1=="---" { mark=1; next; }
$1=="+++" && mark==1 { nextfile; }
{ mark=0; print; }
' "${p}" )"
  printf " done\n"

  printf "  creating patched file list..."
  diffstat -f 4 -r 2 -u -p 0 "${p}"                         \
  |head -n -1                                               \
  |awk '{ for(i=NF;i>=NF-5;i--) { $(i) = ""; } print; }'    \
  |sort                                                     \
  >"diffstat.orig"
  printf " done\n"

  pushd "${base}" >/dev/null 2>&1

  # Check all files exist, up to depth 3
  printf "  checking depth:"
  for((d=0;d<4;d++)); do
    printf " ${d}"
    if do_check_files_at_depth "../diffstat.orig" ${d}; then
      printf " ok, using depth '${d}'\n"
      break
    fi
  done
  if [ ${d} -ge 4 ]; then
    printf "\n"
    printf "  checking depth failed\n"
    read -p "  --> enter patch depth (or Ctrl-C to abort): " d
  fi

  # Store the original list of fiels touched by the patch,
  # removing the $d leading components
  sed -r -e "s:^([^/]+/){${d}}::;" "../diffstat.orig" >"${dst}/${pname}.diffstat.orig"

  # Apply the patch proper, and check it applied cleanly.
  # We can't check with --dry-run because of patches that
  # contain multiple accumulated patches onto a single file.
  printf "  applying patch..."
  if ! patch -g0 -F1 -f -p${d} <"${p}" >"../patch.out" 2>&1; then
    printf " ERROR\n\n"
    popd >/dev/null 2>&1
    printf "There was an error while applying:\n  -->  ${p}  <--\n"
    printf "'${base}' was restored to the state it was prior to applying this faulty patch.\n"
    printf "Here's the 'patch' command, and its output:\n"
    printf "  ----8<----\n"
    printf "  patch -g0 -F1 -f -p${d} <'${p}'\n"
    sed -r -e 's/^/  /;' "patch.out"
    printf "  ----8<----\n"
    exit 1
  fi
  printf " done\n"

  printf "  removing '.orig' files..."
  find . -type f -name '*.orig' -exec rm -f {} +
  printf " done\n"

  popd >/dev/null 2>&1

  printf "  re-diffing the patch..."
  printf "%s\n\n" "${comment}" >"${dst}/${pname}"
  diff -durN "${base}.orig" "${base}" >>"${dst}/${pname}"
  printf " done\n"

  if [ -n "${diff}" ]; then
    printf "  applying diff filter..."
    filterdiff -x "${diff}" "${dst}/${pname}" >"tmp-diff"
    mv "tmp-diff" "${dst}/${pname}"
    printf " done\n"
  fi

  printf "  creating new patched file list..."
  diffstat -f 4 -r 2 -u -p 1 "${dst}/${pname}"              \
  |head -n -1                                               \
  |awk '{ for(i=NF;i>=NF-5;i--) { $(i) = ""; } print; }'    \
  |sort                                                     \
  >"${dst}/${pname}.diffstat.new"
  printf " done\n"

  printf "  removing temporary files/dirs..."
  rm -f "patch.out"
  rm -f "diffstat.tmp"
  rm -f "diffstat.orig"
  rm -rf "${base}.orig"
  printf " done\n"
done

# Scan all new patches to see if they touch
# more files than the original patches
printf "\nChecking resulting patchset:\n"
for p in "${dst}/"*.patch; do
  pname="$( basename "${p}" )"

  if ! cmp "${p}.diffstat.orig" "${p}.diffstat.new" >/dev/null; then
    printf "  --> '${pname}' differ in touched files <--\n"
  else
    rm -f "${p}.diffstat.orig" "${p}.diffstat.new"
  fi
done
printf "  done.\n"
