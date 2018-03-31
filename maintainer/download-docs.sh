#!/bin/bash

distdir=${1:-.}

# Configurable portions
docs_git=https://github.com/crosstool-ng/crosstool-ng.github.io.git
docs_subdir=_pages/docs

# Clone a repository for docs. Github does not support 'git archive --remote='.
set -ex
git clone --depth=1 "${docs_git}" "${distdir}/site-docs"

# Copy the docs instead of the MANUAL_ONLINE placeholder
mkdir -p "${distdir}/docs/manual"
for i in "${distdir}/site-docs/${docs_subdir}/"*.md; do
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
' < "${i}" > "${distdir}/docs/manual/${i##*/}"
done
rm -rf "${distdir}/site-docs"
