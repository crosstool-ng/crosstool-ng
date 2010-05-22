22 May 2010 - Titus von Boxberg

Prerequisites and instructions for using ct-ng for building a cross toolchain on FreeBSD as host.

0) Tested on FreeBSD 8.0

1) Install (at least) the following ports
   archivers/lzma
   textproc/gsed
   devel/gmake
   devel/patch
   shells/bash
   devel/bison
   lang/gawk
   devel/automake110
   ftp/wget

   Of course, you should have /usr/local/bin in your PATH.

2) run ct-ng's configure with the following tool configuration:
   ./configure --with-sed=/usr/local/bin/gsed --with-make=/usr/local/bin/gmake \
   --with-patch=/usr/local/bin/gpatch
   [...other configure parameters as you like...]

3) proceed as described in general documentation
   but use gmake instead of make
