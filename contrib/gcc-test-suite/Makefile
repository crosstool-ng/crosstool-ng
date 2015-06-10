# Helper makefile which downloads (if required) and runs the GCC test suite (DejaGnu)
#
# Note: Before run please make sure to have your toolchain available in your path.
#
# Copyright 2010 DoréDevelopment
# 
# Author: Martin Lund <mgl@doredevelopment.dk>
#
# This program is free software; you can redistribute  it and/or modify it
# under  the terms of  the GNU General  Public License as published by the
# Free Software Foundation;  either version 2 of the  License, or (at your
# option) any later version.
#

# Internal configuration
TARGET:=@@DG_TARGET@@
TOPDIR:=$(shell pwd)
LOGDIR:=$(TOPDIR)/tmp

# Include default configuration
include default.cfg

# Add toolchain to path
PATH:=$(shell cd ../../bin && pwd):$(PATH)

# Select test set
ifeq ($(DG_TOOLNAME),gcc)
	DG_TESTS:=$(DG_C_TESTS)
endif
ifeq ($(DG_TOOLNAME),g++)
	DG_TESTS:=$(DG_CPP_TESTS)
endif

# Check that we have 'runtest' installed
RUNTEST=$(shell which runtest)
ifeq ($(RUNTEST),)
        $(error "DejaGnu 'runtest' not found - please install (eg. apt-get install dejagnu)")
endif

# Targets 
all: test

$(LOGDIR):
	@mkdir -p $@

$(LOGDIR)/site.exp: $(TOPDIR)/default.cfg $(LOGDIR)
	@{ echo 'lappend boards_dir "$(LOGDIR)"'; \
	   echo 'set tmpdir "$(TOPDIR)"'; \
	   echo 'set target_alias $(TARGET)';     } > $@

$(LOGDIR)/board.exp: $(TOPDIR)/default.cfg $(LOGDIR)
	@{ echo 'load_generic_config "unix"';                    \
	   echo 'process_multilib_options ""';                   \
	   echo 'set_board_info bmk,use_alarm 1';                \
	   echo 'set_board_info rsh_prog ssh';                   \
	   echo 'set_board_info rcp_prog scp';                   \
	   echo 'set_board_info hostname $(DG_TARGET_HOSTNAME)'; \
	   echo 'set_board_info username $(DG_TARGET_USERNAME)'; } > $@

# As Martin puts it:
#  > The thing is that when you run 50k+ test cases the odds are that at
#  > least one will fail and thus runtest basically always return an error
#  > despite the fact that the test session has executed successfully.
# So just ignore any error reported by runtest
test: $(LOGDIR)/board.exp $(LOGDIR)/site.exp $(LOGDIR)
	@runtest --tool $(DG_TOOLNAME)          \
	         --srcdir $(TOPDIR)/testsuite   \
	         --objdir $(LOGDIR)             \
	         --outdir $(LOGDIR)             \
	         --all                          \
	         --target $(TARGET)             \
	         --target_board board           \
	         $(DG_TESTS)                    \
	         GXX_UNDER_TEST=$(TARGET)-g++   || true
	@printf "Result files available in '%s'\n" "$(LOGDIR)"

clean:
	rm -rf $(LOGDIR)

.PHONY: config test clean
