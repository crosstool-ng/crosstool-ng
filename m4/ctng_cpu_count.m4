# Find out how to count CPUs
AC_DEFUN([CTNG_CPU_COUNT],
    [AC_CACHE_CHECK([whether to use getconf or sysctl to count CPUs],
        [acx_cv_cpu_count],
        [getconf _NPROCESSORS_ONLN >/dev/null 2>&1 && \
             acx_cv_cpu_count="getconf _NPROCESSORS_ONLN"
         sysctl -n hw.ncpu >/dev/null 2>&1 && \
             acx_cv_cpu_count="sysctl -n hw.ncpu"])
     AC_SUBST(CPU_COUNT, "$acx_cv_cpu_count")
    ])
