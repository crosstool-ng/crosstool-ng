# Check for GNU perf location and the type it uses in the prototypes
AC_DEFUN([CTNG_PROG_GPERF],
    [AX_REQUIRE_DEFINED([CTNG_CHECK_TOOL_REQ])
     CTNG_CHECK_TOOL_REQ([GPERF], [gperf], [gperf])
     # Gperf 3.1 started generating functions with size_t rather than unsigned int
     AC_MSG_CHECKING([for the type used in gperf declarations])
     cat > conftest.gperf.c <<_ASEOF
#include <string.h>"
const char * in_word_set(const char *, GPERF_LEN_TYPE);
_ASEOF
     echo foo,bar | ${GPERF} -L ANSI-C >> conftest.gperf.c
     AS_IF([${CC} -c -o /dev/null conftest.gperf.c -DGPERF_LEN_TYPE='size_t' >/dev/null 2>&1],
            [AC_MSG_RESULT([size_t])
             GPERF_LEN_TYPE='size_t'],
        [${CC} -c -o /dev/null conftest.gperf.c -DGPERF_LEN_TYPE='unsigned int' >/dev/null 2>&1],
            [AC_MSG_RESULT([unsigned int])
             GPERF_LEN_TYPE='unsigned int'],
        [AC_MSG_ERROR([unable to determine gperf len type])])
     rm -f conftest.gperf.c
     AC_DEFINE_UNQUOTED([GPERF_LEN_TYPE], $GPERF_LEN_TYPE, [String length type used by gperf])
])
