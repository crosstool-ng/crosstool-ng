#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.67])
AC_INIT(
    [crosstool-NG],
    [m4_esyscmd_s([git describe --always --dirty])],
    [crossgcc@sourceware.org])
AC_CONFIG_AUX_DIR([scripts])

#--------------------------------------------------------------------
# A few helper macros

# Check for required tool
AC_DEFUN(
    [ACX_CHECK_TOOL_REQ],
    [AC_CHECK_TOOLS([$1], [$2])
     AS_IF(
        [test -z "$$1"],
        [AC_MSG_ERROR([missing required tool: $2])])
    ])

# Check for required tool, set variable to full pathname
AC_DEFUN(
    [ACX_PATH_TOOL_REQ],
    [ACX_CHECK_TOOL_REQ([$1], [$2])
     AS_CASE(
        [$$1],
        [/*],,
        [?*],[AC_MSG_CHECKING([for absolute path to $$1])
              $1=$(which $$1)
              AC_MSG_RESULT([$$1])])])

# Check for required program
AC_DEFUN(
    [ACX_CHECK_PROGS_REQ],
    [AC_CHECK_PROGS([$1], [$2])
     AS_IF(
        [test -z "$$1"],
        [AC_MSG_ERROR([missing required tool: $2])])
    ])

# Check for path to required program
AC_DEFUN(
    [ACX_PATH_PROGS_REQ],
    [AC_PATH_PROGS([$1], [$2])
     AS_IF(
        [test -z "$$1"],
        [AC_MSG_ERROR([missing required tool: $2])])
    ])

# Set the kconfig option
AC_DEFUN(
    [ACX_SET_KCONFIG_OPTION],
    [AS_IF(
        [test -n "$$1"],
        [kconfig_options="$kconfig_options has_$1=y"],
        [kconfig_options="$kconfig_options has_$1"])
    ])

#--------------------------------------------------------------------
# Allow dummy --{en,dis}able-{static,shared}
AC_ARG_ENABLE(
    [local],
    [AS_HELP_STRING(
        [--enable-local],
        [do not install, and use current directory])])
AC_SUBST([enable_local], [${enable_local:-no}])
AC_ARG_ENABLE(
    [shared],
    [AS_HELP_STRING(
        [--enable-shared],
        [build shared libraries (default=yes) (ignored)])])
AC_ARG_ENABLE(
    [static],
    [AS_HELP_STRING(
        [--enable-static],
        [build static libraries (default=yes) (ignored)])])

#---------------------------------------------------------------------
# Check for --build and --host...
AC_CANONICAL_BUILD
AC_CANONICAL_HOST
# ... but refuse --target
AS_IF([test -n "$target_alias"],
      AC_MSG_ERROR([--target is not allowed]))

# Allow program name tranformation (--program-{prefix,suffix,transform-name})
AC_ARG_PROGRAM

#---------------------------------------------------------------------
# Initial checks that are usually done first (I don't know why, that's
# just what I seem to experience...)
#---------------------------------------------------------------------
AC_ARG_WITH([install],
    AS_HELP_STRING([--with-install=PATH],
                   [Specify the full PATH to a BSD-compatible install]),
    [INSTALL=$withval])
AC_PROG_INSTALL
AC_CACHE_VAL([ac_cv_path_GREP],
    [AC_ARG_WITH([grep],
        AS_HELP_STRING([--with-grep=PATH],
                       [Specify the full PATH to GNU grep]),
        [ac_cv_path_GREP=$withval])])
AC_PROG_GREP
AC_PROG_EGREP
AS_IF(
    [test ! "$EGREP" = "$GREP -E"],
    [AC_MSG_ERROR([egrep is not $GREP -E])])
AC_CACHE_VAL([ac_cv_path_SED],
    [AC_ARG_WITH([sed],
        AS_HELP_STRING([--with-sed=PATH],
                       [Specify the full PATH to GNU sed]),
        [ac_cv_path_SED=$withval])])
AC_PROG_SED
AC_MSG_CHECKING([whether sed understands -r -i -e])
touch .ct-ng.sed.test
if ${SED} -r -i -e 's/foo/bar/' .ct-ng.sed.test >/dev/null 2>&1; then
    rm -f .ct-ng.sed.test
    AC_MSG_RESULT([yes])
else
    rm -f .ct-ng.sed.test
    AC_MSG_RESULT([no])
    AC_MSG_ERROR()
fi
AC_PROG_LN_S

#--------------------------------------------------------------------
# A bunch of boring tests...
#--------------------------------------------------------------------
AC_PROG_CC
AS_IF([test -z "$CC"],
      [AC_MSG_ERROR([no suitable compiler found])])
AC_PROG_CPP

# But we still need a way to specify the PATH to GNU versions (Damn MacOS)
AC_ARG_WITH([objcopy],
    AS_HELP_STRING([--with-objcopy=PATH],
                   [Specify the full PATH to GNU objcopy]),
    [OBJCOPY=$withval])
AC_ARG_WITH([objdump],
    AS_HELP_STRING([--with-objdump=PATH],
                   [Specify the full PATH to GNU objdump]),
    [OBJDUMP=$withval])
AC_ARG_WITH([ranlib],
    AS_HELP_STRING([--with-ranlib=PATH],
                   [Specify the full PATH to GNU ranlib]),
    [RANLIB=$withval])
AC_ARG_WITH([readelf],
    AS_HELP_STRING([--with-readelf=PATH],
                   [Specify the full PATH to GNU readelf]),
    [READELF=$withval])
AC_ARG_WITH([gperf],
    AS_HELP_STRING([--with-gperf=PATH],
                   [Specify the full PATH to GNU gperf]),
    [GPERF=$withval])

AC_PROG_RANLIB
ACX_PATH_TOOL_REQ([OBJCOPY], [gobjcopy objcopy])
ACX_PATH_TOOL_REQ([OBJDUMP], [gobjdump objdump])
ACX_PATH_TOOL_REQ([READELF], [greadelf readelf])
ACX_PATH_TOOL_REQ([GPERF], [gperf])

ACX_CHECK_PROGS_REQ([bison], [bison])
ACX_CHECK_PROGS_REQ([flex], [flex])
ACX_CHECK_PROGS_REQ([makeinfo], [makeinfo])
ACX_CHECK_PROGS_REQ([cut], [cut])
ACX_CHECK_PROGS_REQ([stat], [stat])
ACX_CHECK_PROGS_REQ([readlink], [readlink])
ACX_CHECK_PROGS_REQ([wget], [wget])
ACX_CHECK_PROGS_REQ([tar], [tar])
ACX_CHECK_PROGS_REQ([gzip], [gzip])
ACX_CHECK_PROGS_REQ([bzip2], [bzip2])
ACX_CHECK_PROGS_REQ([help2man], [help2man])

#--------------------------------------------------------------------
# Still boring, but remember the path, now...
#--------------------------------------------------------------------
ACX_PATH_TOOL_REQ([PATCH], [gpatch patch])

#--------------------------------------------------------------------
# And a bunch of less boring tests...
#--------------------------------------------------------------------
# We need a bash that is >= 3.1
AC_CACHE_VAL([ac_cv_path__BASH],
    [AC_ARG_WITH([bash],
        AS_HELP_STRING([--with-bash=PATH],
                       [Specify the full PATH to GNU bash >= 3.1]),
        [ac_cv_path__BASH=$withval])])
AC_CACHE_CHECK([for bash >= 3.1], [ac_cv_path__BASH],
    [AC_PATH_PROGS_FEATURE_CHECK([_BASH], [bash],
        [[_BASH_ver=$($ac_path__BASH --version 2>&1 \
                     |$EGREP '^GNU bash, version (3\.[1-9]|4)')
          test -n "$_BASH_ver" && ac_cv_path__BASH=$ac_path__BASH ac_path__BASH_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find bash >= 3.1])])])
AC_SUBST([_BASH], [$ac_cv_path__BASH])

# We need a awk that *is* GNU awk
AC_CACHE_VAL([ac_cv_path__AWK],
    [AC_ARG_WITH([awk],
        AS_HELP_STRING([--with-awk=PATH],
                       [Specify the full PATH to GNU awk]),
        [ac_cv_path__AWK=$withval])])
AC_CACHE_CHECK([for GNU awk], [ac_cv_path__AWK],
    [AC_PATH_PROGS_FEATURE_CHECK([_AWK], [gawk awk],
        [[_AWK_ver=$($ac_path__AWK --version 2>&1 \
                     |$EGREP '^GNU Awk ')
          test -n "$_AWK_ver" && ac_cv_path__AWK=$ac_path__AWK ac_path__AWK_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find GNU awk])])])
AC_SUBST([_AWK], [$ac_cv_path__AWK])

#----------------------------------------
# Check for GNU make 3.80 or above
AC_CACHE_VAL([ac_cv_path_MAKE],
    [AC_ARG_WITH([make],
        AS_HELP_STRING([--with-make=PATH],
                       [Specify the full PATH to GNU make >= 3.80]),
        [ac_cv_path_MAKE=$withval])])
AC_CACHE_CHECK([for GNU make >= 3.80], [ac_cv_path_MAKE],
    [AC_PATH_PROGS_FEATURE_CHECK([MAKE], [gmake make],
        [[MAKE_ver=$($ac_path_MAKE --version 2>&1 \
                     |$EGREP '^GNU Make (3.[89][[:digit:]]|[4-9])')
          test -n "$MAKE_ver" && ac_cv_path_MAKE=$ac_path_MAKE ac_path_MAKE_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find GNU make >= 3.80])])])
AC_SUBST([MAKE], [$ac_cv_path_MAKE])
AC_PROG_MAKE_SET

# Check for GNU make 3.81 exactly, otherwise
# it will be built as a companion tool.
AC_MSG_CHECKING([for make 3.81])
AS_IF(
      [test "$MAKE_ver" = "GNU Make 3.81"],
      [make381="y"
       AC_MSG_RESULT([yes])
      ],
      [make381=
       AC_MSG_RESULT([no])
      ]
     )
ACX_SET_KCONFIG_OPTION([make381])

#----------------------------------------
# Check for libtool >= 1.5.26
AC_CACHE_VAL([ac_cv_path_LIBTOOL],
    [AC_ARG_WITH([libtool],
        AS_HELP_STRING([--with-libtool=PATH],
                       [Specify the full PATH to GNU libtool >= 1.5.26]),
        [ac_cv_path_LIBTOOL=$withval])])
AC_CACHE_CHECK([for GNU libtool >= 1.5.26], [ac_cv_path_LIBTOOL],
    [AC_PATH_PROGS_FEATURE_CHECK([LIBTOOL], [glibtool libtool],
        [[LIBTOOL_ver=$($ac_path_LIBTOOL --version 2>&1 \
                        |$EGREP '\(GNU libtool.*\) (2[[:digit:]]*\.|1\.6[[:digit:]]*\.|1\.5\.[2-9][[:digit:]]+)')
          test -n "$LIBTOOL_ver" && ac_cv_path_LIBTOOL=$ac_path_LIBTOOL ac_path_LIBTOOL_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find GNU libtool >= 1.5.26])])])
AC_SUBST([LIBTOOL], [$ac_cv_path_LIBTOOL])

#----------------------------------------
# Check for libtoolize >= 1.5.26
AC_CACHE_VAL([ac_cv_path_LIBTOOLIZE],
    [AC_ARG_WITH([libtoolize],
        AS_HELP_STRING([--with-libtoolize=PATH],
                       [Specify the full PATH to GNU libtoolize >= 1.5.26]),
        [ac_cv_path_LIBTOOLIZE=$withval])])
AC_CACHE_CHECK([for GNU libtoolize >= 1.5.26], [ac_cv_path_LIBTOOLIZE],
    [AC_PATH_PROGS_FEATURE_CHECK([LIBTOOLIZE], [glibtoolize libtoolize],
        [[LIBTOOLIZE_ver=$($ac_path_LIBTOOLIZE --version 2>&1 \
                        |$EGREP '\(GNU libtool.*\) (2[[:digit:]]*\.|1\.6[[:digit:]]*\.|1\.5\.[2-9][[:digit:]]+)')
          test -n "$LIBTOOLIZE_ver" && ac_cv_path_LIBTOOLIZE=$ac_path_LIBTOOLIZE ac_path_LIBTOOLIZE_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find GNU libtoolize >= 1.5.26])])])
AC_SUBST([LIBTOOLIZE], [$ac_cv_path_LIBTOOLIZE])

#----------------------------------------
# Check for automake >= 1.10
AC_CACHE_VAL([ac_cv_path_automake],
    [AC_ARG_WITH([automake],
        AS_HELP_STRING([--with-automake=PATH],
                       [Specify the full PATH to GNU automake >= 1.10]),
        [ac_cv_path_automake=$withval])])
AC_CACHE_CHECK([for GNU automake >= 1.10], [ac_cv_path_automake],
    [AC_PATH_PROGS_FEATURE_CHECK([automake], [automake],
        [[automake_ver=$($ac_path_automake --version 2>&1 \
                         |$EGREP '\(GNU automake\) (1\.[[:digit:]]{2,}|[2-9][[:digit:]]*\.)')
          test -n "$automake_ver" && ac_cv_path_automake=$ac_path_automake ac_path_automake_found=:]],
        [AC_MSG_RESULT([no])
         AC_MSG_ERROR([could not find GNU automake >= 1.10])])])
AC_SUBST([automake], [$ac_cv_path_automake])

#--------------------------------------------------------------------
# Boring again... But still a bit of work to do...
#--------------------------------------------------------------------
AC_SUBST([kconfig_options])

#----------------------------------------
AC_CHECK_PROGS([xz],   [xz])
ACX_SET_KCONFIG_OPTION([xz])
AS_IF(
    [test -z "$xz"],
    [AC_CHECK_PROGS([lzma], [lzma])])
ACX_SET_KCONFIG_OPTION([lzma])

#----------------------------------------
AC_CHECK_PROGS([cvs], [cvs])
ACX_SET_KCONFIG_OPTION([cvs])

#----------------------------------------
AC_CHECK_PROGS([svn], [svn])
ACX_SET_KCONFIG_OPTION([svn])

#--------------------------------------------------------------------
# Now, for some fun...
#--------------------------------------------------------------------
AC_C_INLINE
AC_HEADER_STDC
AC_FUNC_MALLOC
AC_FUNC_REALLOC
AC_FUNC_ALLOCA

#----------------------------------------
# Check for gettext and libintl for the kconfig frontends
AC_SUBST([gettext])
AC_CHECK_HEADERS(
    [libintl.h],
    [ac_ct_gettext_hdr=$ac_header; break])
AS_IF(
    [test -n "$ac_ct_gettext_hdr"],
    [AC_CHECK_DECL(
        [gettext],
        [gettext=y],,
        [AC_INCLUDES_DEFAULT()
         #include <$ac_ct_gettext_hdr>])])
SAVE_LIBS=$LIBS
AC_SEARCH_LIBS(bindtextdomain, intl, [test "$ac_res" = "none required" || INTL_LIBS="${ac_res}"])
LIBS=$SAVE_LIBS
AC_SUBST([INTL_LIBS])

#----------------------------------------
# Check for ncurses, for the kconfig frontends
AC_SUBST([ac_ct_curses_hdr])
AC_CHECK_HEADERS(
    [ncurses/ncurses.h ncurses/curses.h ncursesw/curses.h ncurses.h curses.h],
    [ac_ct_curses_hdr=$ac_header; break])
AS_IF(
    [test -z "$ac_ct_curses_hdr"],
    [AC_MSG_ERROR([could not find curses header, required for the kconfig frontends])])
AC_SEARCH_LIBS(
    [initscr],
    [ncursesw ncurses curses],
    [ac_ct_curses_lib_found=yes; break])
AS_IF(
    [test -z "$ac_ct_curses_lib_found"],
    [AC_MSG_ERROR([could not find curses library, required for the kconfig frontends])])
AC_SEARCH_LIBS(
    [tgetent],
    [termcap tinfo ncursesw ncurses curses])

#--------------------------------------------------------------------
# Lastly, take care of crosstool-NG internal values
#--------------------------------------------------------------------
# Hey! We need the date! :-)
AC_SUBST(
    [DATE],
    [$(date +%Y%m%d)])

# Decorate the version string if needed
AS_IF(
    [test -f version.sh -a -x version.sh],
    [V=$(./version.sh "${PACKAGE_VERSION}")])
AS_IF(
    [test -n "${V}"],
    [PACKAGE_VERSION="${V}"],
    [AS_CASE(
        [${PACKAGE_VERSION}],
        [git|*+git],
        [rev_id="$( git rev-parse --short HEAD )"
         git diff-index --quiet HEAD || rev_id="${rev_id}-dirty"
         PACKAGE_VERSION="${PACKAGE_VERSION}+${rev_id:-unknown-$( date +%Y%m%d.%H%M%S )}"
        ])])
# Arrange to have no / in the directory name, no need to create an
# arbitrarily deep directory structure
[PACKAGE_VERSION="$( printf "${PACKAGE_VERSION}\n" |"${SED}" -r -e 's:/+:_:g;' )"]

# Handle the local case
AC_SUBST([sublibdir])
AC_SUBST([subdocdir])
AS_IF(
    [test "x$enable_local" = "xyes"],
    [AC_MSG_NOTICE([overiding all of --prefix and the likes, because --enable-local was set])
     prefix=$(pwd)
     exec_prefix="$prefix"
     bindir="$prefix"
     libdir="$prefix"
     sublibdir=""
     docdir="$prefix""/docs"
     subdocdir=""
     datarootdir="$prefix"
     mandir="$docdir"],
    [sublibdir="/\${VERSION}"
     subdocdir="/\${VERSION}"])

#--------------------------------------------------------------------
# Finally, generate the output file(s)
#--------------------------------------------------------------------
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
