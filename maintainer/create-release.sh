#!/bin/bash

# Configurable portions
docs_git=https://github.com/crosstool-ng/crosstool-ng.github.io.git
docs_subdir=_pages/docs
formats=( "bz2" "xz" )
declare -A tar_opt=( ["bz2"]=j ["xz"]=J )
digests=( md5 sha1 sha512 )
use_gpg=yes

do_trace()
{
    echo "  --> $@" >&2
}

do_abort()
{
    echo "ERROR: $@" >&2
    exit 1
}

# Go to the top-level
topdir=`git rev-parse --show-toplevel`
if [ -z "${topdir}" ]; then
    do_abort "Not in the Git clone"
fi
cd "${topdir}"

# Determine the version. Replace the dashes with dots, as packaging
# systems don't expect dashes in versions, but they're ok in package
# name.
version=`git describe | sed -r -e 's,-,.,g' -e 's,^crosstool\.ng\.,crosstool-ng-,'`
do_trace "Creating release for ${version}"

# Create the base working directory
if [ -e "release" -a ! -d "release" ]; then
    do_abort "File 'release' already exists but is not a directory"
fi
mkdir -p "release"

# Copy the base stuff
do_trace "Copying crosstool-NG"
rm -rf "release/${version}"
git archive --prefix="${version}/" HEAD | tar xf - -C "release"

# Clone a repository for docs. Github does not support 'git archive --remote='.
do_trace "Checking out docs"
rm -rf "release/site"
git clone --depth=1 "${docs_git}" "release/site"

# The rest of modifications are inside the release directory
cd "release/${version}"

# Copy the docs instead of the MANUAL_ONLINE placeholder
do_trace "Replacing docs"
rm "docs/MANUAL_ONLINE"
mkdir -p "docs/manual"
for i in "../site/${docs_subdir}/"*.md; do
    awk '
BEGIN   { skip=0; }
        {
            if ($0=="---") {
                if (NR==1) {
                    skip=1
                    next
                }
                else if (skip) {
                    skip=0
                    next
                }
            }
            if (!skip) {
                print $0
            }
        }
' < "${i}" > "docs/manual/${i##*/}"
done

# Run bootstrap before it is removed
do_trace "Bootstrapping"
./bootstrap
rm -f bootstrap

# Remove other things not for the end user
do_trace "Removing unreleased files"
rm -f .travis.*
find -name .gitignore | xargs rm
rm -rf autom4te.cache maintainer

# Go back to top level
cd ../..

# Package up
do_trace "Packaging"
for fmt in "${formats[@]}"; do
    tar c${tar_opt[$fmt]}f "release/${version}.tar.${fmt}" -C "release" "${version}"
    for h in "${digests[@]}"; do
        (cd "release" && ${h}sum "${version}.tar.${fmt}") > "release/${version}.tar.${fmt}.${h}"
    done
    if [ "${use_gpg}" = "yes" ]; then
        (cd "release" && gpg --detach-sign "${version}.tar.${fmt}")
    fi
done
