#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.67])

# FIXME Temporary hack until the next release (we'll switch to plain numeric tags then)
# TBD need to quote sed expression
AC_INIT(
    [crosstool-NG],
    [m4_esyscmd_s([git describe --always --dirty])],
    [crossgcc@sourceware.org],
    [crosstool-ng],
    [http://crosstool-ng.org])
AC_CONFIG_AUX_DIR([scripts])
AC_CONFIG_MACRO_DIR([m4])

# Check if install(1) supports --strip-program=...
AC_DEFUN(
    [ACX_INSTALL_STRIP_PROGRAM],
    [touch conftest
     mkdir conftest.dir
     AC_MSG_CHECKING([if install takes --strip-program option])
     AS_IF([$INSTALL --strip-program=true -s conftest conftest.dir/conftest 2>/dev/null],
        [install_with_strip_program=y
         AC_MSG_RESULT([yes])],
        [AC_MSG_RESULT([no])])
     ACX_SET_KCONFIG_OPTION([install_with_strip_program])
     rm -rf conftest.dir
     rm -f conftest
    ])
     

#--------------------------------------------------------------------
# Allow dummy --{en,dis}able-{static,shared}
AC_ARG_ENABLE(
    [local],
    [AS_HELP_STRING(
        [--enable-local],
        [do not install, and use current directory])])
AC_SUBST([enable_local], [${enable_local:-no}])

# FIXME: I don't know why we have this. Will remove after the 1.24 release.
AC_ARG_ENABLE(
    [shared],
    [AS_HELP_STRING(
        [--enable-shared],
        [build shared libraries (deprecated, ignored)])])
AC_ARG_ENABLE(
    [static],
    [AS_HELP_STRING(
        [--enable-static],
        [build static libraries (deprecated, ignored)])])

# Check for --build and --host...
AC_CANONICAL_BUILD
AC_CANONICAL_HOST
# ... but refuse --target
AS_IF([test -n "$target_alias"],
      AC_MSG_ERROR([--target is not allowed]))

# Allow program name tranformation (--program-{prefix,suffix,transform-name})
AC_ARG_PROGRAM

AC_PROG_MKDIR_P
AC_PROG_LN_S

CTNG_WITH_DEPRECATED([install], [INSTALL])
AC_ARG_VAR([INSTALL], [Specify the full path to a BSD-compatible install])
AC_PROG_INSTALL
ACX_INSTALL_STRIP_PROGRAM

CTNG_WITH_DEPRECATED([grep], [GREP])
AC_ARG_VAR([GREP], [Specify the full path to GNU grep])

# This is not a typo! Prefer GNU grep on macOS if it is installed.
CTNG_PATH_TOOL_REQ([GREP], [ggrep grep], [grep])
CTNG_PATH_TOOL_REQ([EGREP], [gegrep egrep], [egrep])
AC_PROG_GREP
AC_PROG_EGREP

# FIXME: ct-ng assumes this in many places...
AS_IF([test "$EGREP" != "$GREP -E"],
    [AC_MSG_ERROR([egrep is not $GREP -E])])

CTNG_PROG_VERSION_REQ_STRICT([SED],
    [GNU sed >= 4.0],
    [sed],
    [gsed sed],
    ['GNU sed[^0-9]* [4-9]\.'])
AC_ARG_VAR([SED], [Specify the full path to GNU sed])

AC_CONFIG_HEADERS([config.h])

# Modern GCC/GDB releases require C++ support in the compiler
AC_PROG_CC
AC_PROG_CXX
AC_PROG_CPP
AC_PROG_LEX
AC_PROG_YACC
AS_IF([test -z "$CC" -o -z "$CXX"],
      [AC_MSG_ERROR([no suitable compiler found])])

# Check to see if the compiler can link statically
AC_MSG_CHECKING([if $CC can static link])
echo "int main() {}" | ${CC} -static -o /dev/null -xc - > /dev/null 2>&1
static_test=$?
AS_IF([test $static_test -eq 0],
          [static_link=y
           AC_MSG_RESULT([yes])],
      [test $static_test -ne 0],
          [static_link=
           AC_MSG_RESULT([no])])
CTNG_SET_KCONFIG_OPTION([static_link])

AC_PROG_RANLIB
CTNG_PATH_TOOL_REQ([OBJCOPY], [gobjcopy objcopy], [objcopy])
CTNG_PATH_TOOL_REQ([OBJDUMP], [gobjdump objdump], [objdump])
CTNG_PATH_TOOL_REQ([READELF], [greadelf readelf], [readelf])
CTNG_PATH_TOOL_REQ([GPERF], [gperf], [gperf])

CTNG_CHECK_PROGS_REQ([bison], [bison])
CTNG_CHECK_PROGS_REQ([flex], [flex])
CTNG_CHECK_PROGS_REQ([makeinfo], [makeinfo])
CTNG_CHECK_PROGS_REQ([cut], [cut])
CTNG_CHECK_PROGS_REQ([readlink], [readlink])
CTNG_CHECK_PROGS_REQ([tar], [tar])
CTNG_CHECK_PROGS_REQ([gzip], [gzip])
CTNG_CHECK_PROGS_REQ([bzip2], [bzip2])
CTNG_CHECK_PROGS_REQ([xz], [xz])
CTNG_CHECK_PROGS_REQ([help2man], [help2man])

# Not a fatal failure even if we have neither - the tarballs may
# be provided in a local directory.
AC_CHECK_PROGS([wget], [wget])
CTNG_SET_KCONFIG_OPTION([wget])
AC_SUBST([wget])

AC_CHECK_PROGS([curl], [curl])
CTNG_SET_KCONFIG_OPTION([curl])
AC_SUBST([curl])

CTNG_PROG_STAT(
    [CTNG_SET_KCONFIG_OPTION([stat_flavor_GNU], [y])
     CTNG_SET_KCONFIG_OPTION([stat_flavor_BSD])
    ],
    [CTNG_SET_KCONFIG_OPTION([stat_flavor_BSD], [y])
     CTNG_SET_KCONFIG_OPTION([stat_flavor_GNU])
    ])

CTNG_CPU_COUNT

CTNG_PATH_TOOL_REQ([PATCH], [gpatch patch], [patch])

# We need a bash that is >= 3.1
CTNG_PROG_VERSION_REQ_STRICT([BASH_SHELL],
    [GNU bash >= 3.1],
    [bash],
    [bash],
    ['^GNU bash, version (3\.[1-9]|4)'])

# We need a awk that *is* GNU awk
CTNG_PROG_VERSION_REQ_STRICT([AWK],
    [GNU awk],
    [awk],
    [gawk awk],
    ['^GNU Awk '])

# FIXME This checks for tools at the time configure runs. If a tool is later updated
# to satisfy our version requirement, we still won't be able to see that. Or worse,
# downgraded/removed. We should check this and update configure.in options right
# before running kconfig. Our configure should only check for stuff needed to
# build/install crosstool-ng itself.
#----------------------------------------
# Check for GNU make (want 3.81 or above, but will accept as long as any make is found)
CTNG_PROG_VERSION_REQ_ANY([MAKE],
    [GNU make >= 3.81],
    [make],
    [gmake make],
    ['^GNU Make (3\.8[1-9]|3\.9[0-9]|[4-9]\.)'],
    [make_3_81_or_newer])

# Check other companion tools that we may or may not build
CTNG_PROG_VERSION([LIBTOOL],
    [GNU libtool >= 2.4],
    [libtool],
    [glibtool libtool],
    ['\(GNU libtool\) ([3-9]\.|2.[4-9]|2.[1-3][0-9])'],
    [libtool_2_4_or_newer])

CTNG_PROG_VERSION([LIBTOOLIZE],
    [GNU libtoolize >= 2.4],
    [libtoolize],
    [glibtoolize libtoolize],
    ['\(GNU libtool\) ([3-9]\.|2.[4-9]|2.[1-3][0-9])'],
    [libtoolize_2_4_or_newer])

CTNG_PROG_VERSION([AUTOCONF],
    [GNU autoconf >= 2.65],
    [autoconf],
    [autoconf],
    ['\(GNU Autoconf\) ([3-9]\.|2\.[7-9][0-9]|2\.6[5-9])'],
    [autoconf_2_63_or_newer])

CTNG_PROG_VERSION([AUTORECONF],
    [GNU autoreconf >= 2.63],
    [autoreconf],
    [autoreconf],
    ['\(GNU Autoconf\) ([3-9]\.|2\.[7-9][0-9]|2\.6[3-9])'],
    [autoreconf_2_63_or_newer])

CTNG_PROG_VERSION([AUTOMAKE],
    [GNU automake >= 1.15],
    [automake],
    [automake],
    ['\(GNU automake\) ([2-9]\.|1\.[2-9][0-9]|1\.1[5-9])'],
    [automake_1_15_or_newer])

CTNG_PROG_VERSION([M4],
    [GNU m4 >= 1.4.12],
    [m4],
    [gm4 m4],
    ['\(GNU M4\) ([2-9]\.|1\.[5-9]|1\.[1-4][0-9]|1\.4\.[2-9][0-9]|1\.4\.1[2-9])'],
    [gnu_m4_1_4_12_or_newer])

CTNG_PROG_GPERF

AC_SUBST([kconfig_options])

AC_CHECK_PROGS([cvs], [cvs])
CTNG_SET_KCONFIG_OPTION([cvs])

AC_CHECK_PROGS([svn], [svn])
CTNG_SET_KCONFIG_OPTION([svn])

AC_CHECK_PROGS([git], [git])
CTNG_SET_KCONFIG_OPTION([git])

AC_CHECK_PROGS([DPKG_BUILDFLAGS], [dpkg-buildflags])

# FIXME why checking if not using the result? We don't provide replacemant malloc/alloca/...
AC_C_INLINE
AC_HEADER_STDC
AC_FUNC_MALLOC
AC_FUNC_REALLOC
AC_FUNC_ALLOCA

AM_GNU_GETTEXT([external])

# For now, curses are needed to build kconfig. We may support a command-line
# only configuration without curses later. For now, fail in configure but
# consider it ok in config.h.
AX_WITH_CURSES
AS_IF([test "x$ax_cv_curses" != "xyes" ], [AC_MSG_ERROR([curses library not found])])
AX_WITH_CURSES_PANEL
AS_IF([test "x$ax_cv_panel" != "xyes" ], [AC_MSG_ERROR([panel library not found])])
AX_WITH_CURSES_MENU
AS_IF([test "x$ax_cv_menu" != "xyes" ], [AC_MSG_ERROR([menu library not found])])

AH_BOTTOM([
/* Select the correct curses/menu/panel headers */
#if defined HAVE_NCURSESW_CURSES_H
#  define CURSES_LOC <ncursesw/curses.h>
#elif defined HAVE_NCURSESW_H
#  define CURSES_LOC <ncursesw.h>
#elif defined HAVE_NCURSES_CURSES_H
#  define CURSES_LOC <ncurses/curses.h>
#elif defined HAVE_NCURSES_H
#  define CURSES_LOC <ncurses.h>
#elif defined HAVE_CURSES_H
#  define CURSES_LOC <curses.h>
#else
#  /* not an error - maybe a configuration didn't need curses */
#endif

#if defined HAVE_NCURSESW_PANEL_H
#  define PANEL_LOC <ncursesw/panel.h>
#elif defined HAVE_NCURSES_PANEL_H
#  define PANEL_LOC <ncurses/panel.h>
#elif defined HAVE_PANEL_H
#  define PANEL_LOC <panel.h>
#else
#  /* not an error */
#endif

#if defined HAVE_NCURSESW_MENU_H
#  define MENU_LOC <ncursesw/menu.h>
#elif defined HAVE_NCURSES_MENU_H
#  define MENU_LOC <ncurses/menu.h>
#elif defined HAVE_MENU_H
#  define MENU_LOC <menu.h>
#else
#  /* not an error */
#endif
])

AX_BUILD_DATE_EPOCH(DATE, [%c])
AC_SUBST([DATE])

# Decorate the version string per user-supplied version.sh, if any
AS_IF(
    [test -f version.sh -a -x version.sh],
    [PACKAGE_VERSION=$(./version.sh "${PACKAGE_VERSION}")])

# We are not installing dynamic libraries that need to be found by dynamic linker.
# Install into a subdirectory.
libdir=${libdir}/${PACKAGE_TARNAME}

# Handle the local case
AS_IF(
    [test "x$enable_local" = "xyes"],
    [AC_MSG_NOTICE([overiding all of --prefix and the likes, because --enable-local was set])
     prefix=$(pwd)
     exec_prefix="$prefix"
     bindir="$prefix"
     libdir="$prefix"
     docdir="$prefix""/docs"
     datarootdir="$prefix"
     mandir="$docdir"])

AC_CONFIG_FILES([
    Makefile
    kconfig/Makefile
    config/configure.in
])

AC_OUTPUT
