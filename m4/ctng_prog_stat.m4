# Check that stat(1) is present and determine the syntax for the format
# string (BSD or GNU). Defines ac_cv_stat_flavor to either GNU or BSD;
# and evaluates either IF-GNU or IF-BSD expression.
#   CTNG_PROG_STAT([IF-GNU], [IF-BSD])
AC_DEFUN([CTNG_PROG_STAT_FORMAT],
    [AC_CACHE_CHECK([whether stat takes GNU or BSD format],
         [ctng_cv_stat_flavor],
         [touch conftest
          chmod 642 conftest
          attr_bsd=$(stat -f '%Lp' conftest 2>conftest.stderr.bsd)
          CTNG_MSG_LOG_ENVVAR([attr_bsd], [stat -f output])
          CTNG_MSG_LOG_FILE([conftest.stderr.bsd])
          attr_gnu=$(stat -c '%a' conftest 2>conftest.stderr.gnu)
          CTNG_MSG_LOG_ENVVAR([attr_gnu], [stat -c output])
          CTNG_MSG_LOG_FILE([conftest.stderr.gnu])
          rm -f conftest conftest.stderr.*
          AS_IF([test "$attr_bsd" = "642"],
              [ctng_cv_stat_flavor=BSD],
              [test "$attr_gnu" = "642"],
              [ctng_cv_stat_flavor=GNU],
              [ctng_cv_stat_flavor=unknown])])
     AS_IF([test "$ctng_cv_stat_flavor" = "GNU" ], [$1],
        [test "$ctng_cv_stat_flavor" = "BSD" ], [$2],
        [AC_MSG_ERROR([cannot determine stat(1) format option])])
    ])

AC_DEFUN([CTNG_PROG_STAT],
    [AX_REQUIRE_DEFINED([CTNG_CHECK_PROGS_REQ])
     CTNG_CHECK_PROGS_REQ([stat], [stat])
     CTNG_PROG_STAT_FORMAT(
        [CTNG_SET_KCONFIG_OPTION([stat_flavor_GNU], [y])
         CTNG_SET_KCONFIG_OPTION([stat_flavor_BSD])],
        [CTNG_SET_KCONFIG_OPTION([stat_flavor_BSD], [y])
         CTNG_SET_KCONFIG_OPTION([stat_flavor_GNU])])
    ])
