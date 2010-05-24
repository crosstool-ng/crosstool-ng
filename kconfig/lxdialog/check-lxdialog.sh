#!/bin/sh
# Check ncurses compatibility

OS=`uname`

# Under MACOS make sure that the macports-installed version is used.
case "$OS" in
	Darwin) BASEDIR="/opt/local";;
	*)      BASEDIR="/usr";;
esac

INCLUDEPATH="${BASEDIR}/include"
LIBPATH="${BASEDIR}/lib"

# What library to link
ldflags()
{
	for ext in so a dylib ; do
		for lib in ncursesw ncurses curses ; do
			if [ -f "${LIBPATH}/lib${lib}.${ext}" ]; then
				echo "-L${LIBPATH} -l${lib}"
				exit
			fi
		done
	done
	exit 1
}

# Where is ncurses.h?
ccflags()
{
	if [ -f "${INCLUDEPATH}/ncursesw/ncurses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<ncursesw/ncurses.h>\""
	elif [ -f "${INCLUDEPATH}/ncurses/ncurses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<ncurses/ncurses.h>\""
	elif [ -f "${INCLUDEPATH}/ncursesw/curses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<ncursesw/curses.h>\""
	elif [ -f "${INCLUDEPATH}/ncurses/curses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<ncurses/curses.h>\""
	elif [ -f "${INCLUDEPATH}/ncurses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<ncurses.h>\""
	elif [ -f "${INCLUDEPATH}/curses.h" ]; then
		echo "-I${INCLUDEPATH} \"-DCURSES_LOC=<curses.h>\""
	else
		exit 1
	fi
}

# Temp file, try to clean up after us
tmp=.lxdialog.tmp
trap "rm -f $tmp" 0 1 2 3 15

# Check if we can link to ncurses
check() {
        IF=`echo $(ccflags) | sed -e 's/"//g'`
        $cc $IF $(ldflags) -xc - -o $tmp 2>/dev/null <<'EOF'
#include CURSES_LOC
main() {}
EOF
	if [ $? != 0 ]; then
	    echo " *** Unable to find the ncurses libraries or the"       1>&2
	    echo " *** required header files."                            1>&2
	    echo " *** 'make menuconfig' requires the ncurses libraries." 1>&2
	    echo " *** "                                                  1>&2
	    echo " *** Install ncurses (ncurses-devel) and try again."    1>&2
	    echo " *** "                                                  1>&2
	    exit 1
	fi
}

usage() {
	printf "Usage: $0 [-check compiler options|-ccflags|-ldflags compiler options]\n"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

cc=""
case "$1" in
	"-check")
		shift
		cc="$@"
		check
		;;
	"-ccflags")
		ccflags
		;;
	"-ldflags")
		shift
		cc="$@"
		ldflags
		;;
	"*")
		usage
		exit 1
		;;
esac
