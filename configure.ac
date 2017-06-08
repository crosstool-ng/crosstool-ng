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

# ACX_WITH_DEPRECATED(PROG, VAR)
# Declare a deprecated --with option: instead of --with-PROG=xxx, must use VAR=xxx
AC_DEFUN(
    [ACX_WITH_DEPRECATED],
    [AC_ARG_WITH([$1],
                 [AS_HELP_STRING([--with-$1=PATH],
                                 [Deprecated; use $2=PATH instead])],
                 [AC_MSG_ERROR([--with-$1=$withval deprecated; use $2=$withval instead])])
    ])

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
    [ACX_WITH_DEPRECATED([$3], [$1])
     AC_ARG_VAR([$1], [Specify the full path to GNU $3])
     ACX_CHECK_TOOL_REQ([$1], [$2])
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
     [AC_SUBST([KCONFIG_$1], ["def_bool y"])],
     [AC_SUBST([KCONFIG_$1], ["bool"])])])

# Check if a given program is available with a particular version.
#   ACX_PROG_VERSION(VAR, HELP, PROG, SRCH, VERSION_CHECK[, CONFIG_OPT])
# Search for PROG under possible names of SRCH. Allow user overrides in variable
# VAR; display HELP message. Try to find a version that satisfies VERSION_CHECK
# regexp; if that is achieved, set CONFIG_OPT in the kconfig. Otherwise, settle
# for any version found.
# Sets acx_version_VAR_ok to ':' if the version met the criterion, or false otherwise.
AC_DEFUN(
    [ACX_PROG_VERSION],
    [AS_IF([test -z "$EGREP"],
         [AC_MSG_ERROR([This macro can only be used after checking for EGREP])])
     ACX_WITH_DEPRECATED([$3], [$1])
     AC_ARG_VAR([$1], [Specify the full path to $2])
     acx_version_$1_ok=false
     AC_CACHE_CHECK([for $3], [ac_cv_path_$1],
         [AC_PATH_PROGS_FEATURE_CHECK([$1], [$4],
              [[ver=`$ac_path_$1 --version 2>/dev/null| $EGREP $5`
                test -z "$ac_cv_path_$1" && ac_cv_path_$1=$ac_path_$1
                test -n "$ver" && ac_cv_path_$1="$ac_path_$1" ac_path_$1_found=: acx_version_$1_ok=:]])])
     AS_IF([test -n "$1"],
         [[ver=`$ac_path_$1 --version 2>/dev/null| $EGREP $5`
           test -n "$ver" && acx_version_$1_ok=:]])
     AC_MSG_CHECKING([for $2])
     AS_IF([$acx_version_$1_ok],
         [AC_MSG_RESULT([yes])],
         [AC_MSG_RESULT([no])])
     AC_SUBST([$1], [$ac_cv_path_$1])
     AS_IF([test -n "$6"],
         [AS_IF([$acx_version_$1_ok], [$6=y], [$6=])
          ACX_SET_KCONFIG_OPTION([$6])])
    ])

# Same as above, but make it a fatal error if the tool is not found at all
# (i.e. "require any version, prefer version X or newer")
AC_DEFUN(
    [ACX_PROG_VERSION_REQ_ANY],
    [ACX_PROG_VERSION([$1], [$2], [$3], [$4], [$5], [$6])
     AS_IF([test -z "$$1"],
         [AC_MSG_ERROR([Required tool not found: $3])])
    ])

# Same, but also require the version check to pass
# (i.e. "require version X or newer")
AC_DEFUN(
    [ACX_PROG_VERSION_REQ_STRICT],
    [ACX_PROG_VERSION([$1], [$2], [$3], [$4], [$5], [$6])
     AS_IF([test -z "$$1" || ! $acx_version_$1_ok],
         [AC_MSG_ERROR([Required tool not found: $2])])
    ])

#--------------------------------------------------------------------
# Allow dummy --{en,dis}able-{static,shared}
AC_ARG_ENABLE(
    [local],
    [AS_HELP_STRING(
        [--enable-local],
        [do not install, and use current directory])])
AC_SUBST([enable_local], [${enable_local:-no}])

# FIXME: I don't know why we have this. Will remove after the next
# release.
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
ACX_WITH_DEPRECATED([install], [INSTALL])
AC_ARG_VAR([INSTALL], [Specify the full path to a BSD-compatible install])
AC_PROG_INSTALL

ACX_WITH_DEPRECATED([grep], [GREP])
AC_ARG_VAR([GREP], [Specify the full path to GNU grep])

# This is not a typo! Prefer GNU grep on macOS if it is installed.
ACX_PATH_TOOL_REQ([GREP], [ggrep grep], [grep])
ACX_PATH_TOOL_REQ([EGREP], [gegrep egrep], [egrep])
AC_PROG_GREP
AC_PROG_EGREP
AS_IF([test "$EGREP" != "$GREP -E"],
    [AC_MSG_ERROR([egrep is not $GREP -E])])

ACX_PROG_VERSION_REQ_STRICT([SED],
    [GNU sed >= 4.0],
    [sed],
    [gsed sed],
    ['GNU sed[^0-9]* [4-9]\.'])
AC_ARG_VAR([SED], [Specify the full path to GNU sed])

AC_PROG_LN_S

#--------------------------------------------------------------------
# A bunch of boring tests...
#--------------------------------------------------------------------
# Modern GCC/GDB releases require C++ support in the compiler
AC_PROG_CC
AC_PROG_CXX
AS_IF([test -z "$CC" -o -z "$CXX"],
      [AC_MSG_ERROR([no suitable compiler found])])
AC_PROG_CPP

#---------------------------------------------------------------------
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
ACX_SET_KCONFIG_OPTION([static_link])

AC_PROG_RANLIB
ACX_PATH_TOOL_REQ([OBJCOPY], [gobjcopy objcopy], [objcopy])
ACX_PATH_TOOL_REQ([OBJDUMP], [gobjdump objdump], [objdump])
ACX_PATH_TOOL_REQ([READELF], [greadelf readelf], [readelf])
ACX_PATH_TOOL_REQ([GPERF], [gperf], [gperf])

ACX_CHECK_PROGS_REQ([bison], [bison])
ACX_CHECK_PROGS_REQ([flex], [flex])
ACX_CHECK_PROGS_REQ([makeinfo], [makeinfo])
ACX_CHECK_PROGS_REQ([cut], [cut])
ACX_CHECK_PROGS_REQ([readlink], [readlink])
ACX_CHECK_PROGS_REQ([tar], [tar])
ACX_CHECK_PROGS_REQ([gzip], [gzip])
ACX_CHECK_PROGS_REQ([bzip2], [bzip2])
ACX_CHECK_PROGS_REQ([xz], [xz])
ACX_CHECK_PROGS_REQ([help2man], [help2man])

# Not a fatal failure even if we have neither - the tarballs may
# be provided in a local directory.
AC_CHECK_PROGS([wget], [wget])
ACX_SET_KCONFIG_OPTION([wget])
AC_SUBST([wget])

AC_CHECK_PROGS([curl], [curl])
ACX_SET_KCONFIG_OPTION([curl])
AC_SUBST([curl])

ACX_CHECK_PROGS_REQ([stat], [stat])
AC_CACHE_CHECK([whether stat takes GNU or BSD format],
    [acx_cv_stat_flavor],
    [touch conftest
     chmod 642 conftest
     attr_bsd=`stat -f '%Lp' conftest 2>/dev/null`
     attr_gnu=`stat -c '%a' conftest 2>/dev/null`
     rm -f conftest
     AS_IF([test "$attr_bsd" = "642"],
       [acx_cv_stat_flavor=BSD],
       [test "$attr_gnu" = "642"],
       [acx_cv_stat_flavor=GNU],
       [AC_MSG_ERROR([cannot determine stat(1) format option])])])

# FIXME: support SET_KCONFIG_OPTION with string values? But then
# again, these checks may be moved into ct-ng script.
test "$acx_cv_stat_flavor" = "BSD" && stat_flavor_BSD=y
ACX_SET_KCONFIG_OPTION([stat_flavor_BSD])
test "$acx_cv_stat_flavor" = "GNU" && stat_flavor_GNU=y
ACX_SET_KCONFIG_OPTION([stat_flavor_GNU])

#Find out how to count CPUs
AC_CACHE_CHECK([whether to use getconf or sysctl to count CPUs],
    [acx_cv_cpu_count],
    [getconf _NPROCESSORS_ONLN >/dev/null 2>&1 && \
         acx_cv_cpu_count="getconf _NPROCESSORS_ONLN"
     sysctl -n hw.ncpu >/dev/null 2>&1 && \
         acx_cv_cpu_count="sysctl -n hw.ncpu"])
AC_SUBST(CPU_COUNT, "$acx_cv_cpu_count")

#--------------------------------------------------------------------
# Still boring, but remember the path, now...
#--------------------------------------------------------------------
ACX_PATH_TOOL_REQ([PATCH], [gpatch patch], [patch])

#--------------------------------------------------------------------
# And a bunch of less boring tests...
#--------------------------------------------------------------------
# We need a bash that is >= 3.1
ACX_PROG_VERSION_REQ_STRICT([BASH_SHELL],
    [GNU bash >= 3.1],
    [bash],
    [bash],
    ['^GNU bash, version (3\.[1-9]|4)'])

# We need a awk that *is* GNU awk
ACX_PROG_VERSION_REQ_STRICT([AWK],
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
ACX_PROG_VERSION_REQ_ANY([MAKE],
    [GNU make >= 3.81],
    [make],
    [gmake make],
    ['^GNU Make (3\.8[1-9]|3\.9[0-9]|[4-9]\.)'],
    [make_3_81_or_newer])

# Check other companion tools that we may or may not build
ACX_PROG_VERSION([LIBTOOL],
    [GNU libtool >= 2.4],
    [libtool],
    [glibtool libtool],
    ['\(GNU libtool\) ([3-9]\.|2.[4-9]|2.[1-3][0-9])'],
    [libtool_2_4_or_newer])

ACX_PROG_VERSION([LIBTOOLIZE],
    [GNU libtoolize >= 2.4],
    [libtoolize],
    [glibtoolize libtoolize],
    ['\(GNU libtool\) ([3-9]\.|2.[4-9]|2.[1-3][0-9])'],
    [libtoolize_2_4_or_newer])

ACX_PROG_VERSION([AUTOCONF],
    [GNU autoconf >= 2.65],
    [AUTOCONF],
    [autoconf],
    ['\(GNU Autoconf\) ([3-9]\.|2\.[7-9][0-9]|2\.6[5-9])'],
    [autoconf_2_63_or_newer])

ACX_PROG_VERSION([AUTORECONF],
    [GNU autoreconf >= 2.63],
    [autoreconf],
    [autoreconf],
    ['\(GNU Autoconf\) ([3-9]\.|2\.[7-9][0-9]|2\.6[3-9])'],
    [autoreconf_2_63_or_newer])

ACX_PROG_VERSION([AUTOMAKE],
    [GNU automake >= 1.15],
    [automake],
    [automake],
    ['\(GNU automake\) ([2-9]\.|1\.[2-9][0-9]|1\.1[5-9])'],
    [automake_1_15_or_newer])

ACX_PROG_VERSION([M4],
    [GNU m4 >= 1.4.12],
    [m4],
    [gm4 m4],
    ['\(GNU M4\) ([2-9]\.|1\.[5-9]|1\.[1-4][0-9]|1\.4\.[2-9][0-9]|1\.4\.1[2-9])'],
    [gnu_m4_1_4_12_or_newer])

#----------------------------------------
# Gperf 3.1 started generating functions with size_t rather than unsigned int
AC_MSG_CHECKING([for the type used in gperf declarations])
echo "#include <string.h>" > conftest.gperf.c
echo "const char * in_word_set(const char *, GPERF_LEN_TYPE);" >> conftest.gperf.c
echo foo,bar | ${GPERF} -L ANSI-C >> conftest.gperf.c
AS_IF([${CC} -c -o /dev/null conftest.gperf.c -DGPERF_LEN_TYPE='size_t' >/dev/null 2>&1],
            [AC_MSG_RESULT([size_t])
             GPERF_LEN_TYPE='size_t'],
        [${CC} -c -o /dev/null conftest.gperf.c -DGPERF_LEN_TYPE='unsigned int' >/dev/null 2>&1],
            [AC_MSG_RESULT([unsigned int])
             GPERF_LEN_TYPE='unsigned int'],
        [AC_MSG_ERROR([unable to determine gperf len type])])
rm -f conftest.gperf.c
AC_SUBST([GPERF_LEN_TYPE])

#--------------------------------------------------------------------
# Boring again... But still a bit of work to do...
#--------------------------------------------------------------------
AC_SUBST([kconfig_options])

#----------------------------------------
AC_CHECK_PROGS([cvs], [cvs])
ACX_SET_KCONFIG_OPTION([cvs])

#----------------------------------------
AC_CHECK_PROGS([svn], [svn])
ACX_SET_KCONFIG_OPTION([svn])

AC_CHECK_PROGS([git], [git])
ACX_SET_KCONFIG_OPTION([git])

AC_CHECK_PROGS([DPKG_BUILDFLAGS], [dpkg-buildflags])

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
AC_CONFIG_FILES([Makefile kconfig/Makefile config/configure.in])
AC_OUTPUT
