#!/bin/bash

# Helper script to generate package chksum from a given tarball.

die()
{
  echo "ERROR: $@"
  exit 1
}

[ $# != 1 ] && die "Usage: $0 <package.tar.gz>"

for s in md5 sha1 sha256 sha512
do
  echo "${s} `basename ${1}` `${s}sum ${1} | cut -f1 -d' '`"
done
