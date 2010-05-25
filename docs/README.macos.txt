22 May 2010 - Titus

Prerequisites and instructions for using crosstool-NG for building a cross
toolchain on MacOS as host.

0) Mac OS Snow Leopard, with Developer Tools 3.2 installed, or
   Mac OS Leopard, with Developer Tools & newer gcc (>= 4.3) installed
   via macports

1) You have to use a case sensitive file system for ct-ng's build and target
   directories. Use a disk or disk image with a case sensitive fs that you
   mount somewhere.

2) Install macports (or similar easy means of installing 3rd party software),
   make sure that macport's bin dir is in your PATH.
   Furtheron assuming it is /opt/local/bin.

3) Install (at least) the following macports
   ncurses
   lzmautils
   libtool
   binutils
   gsed
   gawk
   gcc43 (only necessary for Leopard OSX 10.5)

   On Leopard, make sure that the macport's gcc is called with the default
   commands (gcc, g++,...), e.g. via macport gcc_select

4) run ct-ng's configure with the following tool configuration
   (assuming you have installed the tools via macports in /opt/local):
   ./configure --with-sed=/opt/local/bin/gsed           \
               --with-libtool=/opt/local/bin/glibtool   \
               --with-objcopy=/opt/local/bin/gobjcopy   \
               --with-objdump=/opt/local/bin/gobjdump   \
               --with-readelf=/opt/local/bin/greadelf   \
               [...other configure parameters as you like...]

5) proceed as described in standard documentation
