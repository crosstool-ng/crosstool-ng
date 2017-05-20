From: Juan Cespedes <cespedes@debian.org>
Description: fixed FTBFS on alpha
  don't include "debug.h" twice
Last-Update: 2014-01-02
Bug-Debian: http://bugs.debian.org/678721


--- ltrace-0.7.3.orig/sysdeps/linux-gnu/alpha/trace.c
+++ ltrace-0.7.3/sysdeps/linux-gnu/alpha/trace.c
@@ -29,7 +29,6 @@
 
 #include "proc.h"
 #include "common.h"
-#include "debug.h"
 
 #if (!defined(PTRACE_PEEKUSER) && defined(PTRACE_PEEKUSR))
 # define PTRACE_PEEKUSER PTRACE_PEEKUSR
