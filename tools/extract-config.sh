#!/bin/bash

# This scripts extracts a crosstool-NG configuration from the log file
# of a toolchain build with crosstool-NG.

# Usage: cat <logfile> |$0

awk '
BEGIN {
  dump = 0;
}

$0~/Dumping crosstool-NG configuration: done in.+s$/ {
  dump = 0;
}

dump == 1 { $1 = "" }
dump == 1

$0~/Dumping crosstool-NG configuration$/ {
  dump = 1;
}
' |cut -d ' ' -f 2-
