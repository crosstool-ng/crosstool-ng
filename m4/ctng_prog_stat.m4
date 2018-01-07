# Check that stat(1) is present and determine the syntax for the format
# string (BSD or GNU).
AC_DEFUN([CTNG_PROG_STAT],
    [AX_REQUIRE_DEFINED([CTNG_CHECK_PROGS_REQ])
     CTNG_CHECK_PROGS_REQ([stat], [stat])
     AC_CACHE_CHECK([whether stat takes GNU or BSD format],
         [acx_cv_stat_flavor],
         [touch conftest
          chmod 642 conftest
          attr_bsd=$(stat -f '%Lp' conftest 2>/dev/null)
          attr_gnu=$(stat -c '%a' conftest 2>/dev/null)
          rm -f conftest
          AS_IF([test "$attr_bsd" = "642"],
              [acx_cv_stat_flavor=BSD],
              [test "$attr_gnu" = "642"],
              [acx_cv_stat_flavor=GNU],
              [AC_MSG_ERROR([cannot determine stat(1) format option])])])
    ])
