# ===========================================================================
#   Based on:  https://www.gnu.org/software/autoconf-archive/ax_python.html
# ===========================================================================
#
# SYNOPSIS
#
#   CTNG_PYTHON
#
# DESCRIPTION
#
#   This macro does a complete Python development environment check.
#
#   It checks for all known versions. When it finds an executable, it looks
#   to find the header files and library.
#
#   It sets PYTHON_BIN to the name of the python executable,
#   PYTHON_INCLUDE_DIR to the directory holding the header files, and
#   PYTHON_LIB to the name of the Python library.
#
#   This macro calls AC_SUBST on PYTHON_BIN (via AC_CHECK_PROG),
#   PYTHON_INCLUDE_DIR and PYTHON_LIB.
#
#   Also calls CTNG_SET_KCONFIG_OPTION to set KCONFIG_python for
#   crosstool-ng.
#
# LICENSE
#
#   Copyright (c) 2008 Michael Tindal
#   Copyright (c) 2023 Bryan Hundven
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the
#   Free Software Foundation; either version 2 of the License, or (at your
#   option) any later version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
#   Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program. If not, see <https://www.gnu.org/licenses/>.
#
#   As a special exception, the respective Autoconf Macro's copyright owner
#   gives unlimited permission to copy, distribute and modify the configure
#   scripts that are the output of Autoconf when processing the Macro. You
#   need not follow the terms of the GNU General Public License when using
#   or distributing such scripts, even though portions of the text of the
#   Macro appear in them. The GNU General Public License (GPL) does govern
#   all other use of the material that constitutes the Autoconf Macro.
#
#   This special exception to the GPL applies to versions of the Autoconf
#   Macro released by the Autoconf Archive. When you make and distribute a
#   modified version of the Autoconf Macro, you may extend this special
#   exception to the GPL to apply to your modified version as well.

#serial 21

AC_DEFUN([CTNG_PYTHON],
[
  AC_MSG_CHECKING(for python build information)
  AC_MSG_RESULT([])
  for python in python3.13 python3.12 python3.11 python3.10 python3.9 python3.8 python3.7 dnl
python3.6 python3.5 python3.4 python3.3 python3.2 python3.1 python3.0 python2.7 dnl
python2.6 python2.5 python2.4 python2.3 python2.2 python2.1 python; do
    AC_PATH_PROGS(PYTHON_BIN, [$python])
    AC_CHECK_PROGS(PYTHON_BIN_, [$python])
    ctng_python_bin=$PYTHON_BIN
    ctng_python_bin_=$PYTHON_BIN_
    if test "$ctng_python_bin" != ""; then
      AC_CHECK_LIB($ctng_python_bin_, main, ctng_python_lib=$ctng_python_bin_, ctng_python_lib=no)
      if test "$ctng_python_lib" = "no"; then
        AC_CHECK_LIB(${ctng_python_bin_}m, main, ctng_python_lib=${ctng_python_bin_}m, ctng_python_lib=no)
      fi
      if test "$ctng_python_lib" != "no"; then
        $ctng_python_bin -c 'import sysconfig' 2>&1
        if test $? -eq 0; then
          ctng_python_header=$($ctng_python_bin -c "from sysconfig import get_config_var; print(get_config_var('CONFINCLUDEPY'))")
        else
          ctng_python_header=$($ctng_python_bin -c "from distutils.sysconfig import *; print(get_config_var('CONFINCLUDEPY'))")
        fi
        if test "$ctng_python_header" != ""; then
          break;
        fi
      fi
    fi
  done

  python=n
  AS_IF([test "$ctng_python_bin" = ""],
        ctng_python_bin=no,
        python=y)
  CTNG_SET_KCONFIG_OPTION([python])

  AS_IF([test "$ctng_python_header" = ""],
        ctng_python_header=no)

  AS_IF([test "$ctng_python_lib" = ""],
        ctng_python_lib=no)

  AC_MSG_RESULT([  results of the Python check:])
  AC_MSG_RESULT([    Binary:      $ctng_python_bin])
  AC_MSG_RESULT([    Library:     $ctng_python_lib])
  AC_MSG_RESULT([    Include Dir: $ctng_python_header])

  AS_IF([test "$ctng_python_header" != "no"],
        [PYTHON_INCLUDE_DIR=$ctng_python_header
         AC_SUBST(PYTHON_INCLUDE_DIR)])

  AS_IF([test "$ctng_python_lib" != "no"],
        [PYTHON_LIB=$ctng_python_lib
         AC_SUBST(PYTHON_LIB)])
])dnl
