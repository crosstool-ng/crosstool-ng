# CTNG_PYTHON_VERSION([major],[minor])
#
# Check for at least a specific Major.Minor of python.
# Don't error out if it isn't matched... Might go back on that.
AC_DEFUN([CTNG_PYTHON_VERSION],
[
  AC_MSG_CHECKING(for python version greater than $1.$2)

  pyvermajor=$($PYTHON_BIN -c "import sys; print(sys.version_info.major)")
  pyverminor=$($PYTHON_BIN -c "import sys; print(sys.version_info.minor)")

  AS_IF([test $pyvermajor -ge $1 -a $pyverminor -ge $2],
        eval "python_$1_$2_or_newer=y"
        [CTNG_SET_KCONFIG_OPTION([python_$1_$2_or_newer])
        AC_MSG_RESULT([yes: ${pyvermajor}.${pyverminor}])],
        AC_MSG_RESULT([no: ${pyvermajor}.${pyverminor}]))
])dnl
