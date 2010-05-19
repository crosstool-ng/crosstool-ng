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

# Internal directory configuration
TOPDIR=${shell pwd}
TMPDIR=${TOPDIR}/tmp

# Include default configuration
include default.cfg

# Add toolchain to path
PATH:=${DG_TOOLCHAIN_DIR}:${PATH}

# Select test set
ifeq (${DG_TOOLNAME},gcc)
	DG_TESTS=$(DG_C_TESTS)
endif
ifeq (${DG_TOOLNAME},g++)
	DG_TESTS=$(DG_CPP_TESTS)
endif

# Check that we have 'runtest' installed
RUNTEST=$(shell which runtest)
ifeq "${RUNTEST}" ""
        $(error "DejaGnu 'runtest' not found - please install (eg. apt-get install dejagnu)")
endif

# Targets 
all: test

gcc-testsuite-${DG_GCC_VERSION}.tar.gz:
#	wget -nc ${DG_GCC_URL}
    
gcc-${DG_GCC_VERSION}: gcc-testsuite-${DG_GCC_VERSION}.tar.gz
#	tar xzf gcc-testsuite-${DG_GCC_VERSION}.tar.gz

config:
	@mkdir -p ${TMPDIR}
	@{ echo 'lappend boards_dir "."'; \
	  echo "set target_alias ${DG_TARGET}"; } > ${TMPDIR}/site.exp
	@{ echo -e "load_generic_config \"unix\""; \
	echo -e "process_multilib_options \"\"" ; \
	echo "set_board_info bmk,use_alarm 1" ; \
	echo "set_board_info rsh_prog ssh" ; \
	echo "set_board_info rcp_prog scp" ; \
	echo "set_board_info hostname ${DG_TARGET_HOSTNAME}"; \
	echo "set_board_info username ${DG_TARGET_USERNAME}"; } > ${TMPDIR}/board.exp

test: gcc-${DG_GCC_VERSION} config
	cd ${TMPDIR} && \
	runtest	--tool ${DG_TOOLNAME} \
		--srcdir ${DG_SRC_DIR} \
		--all \
		--target ${DG_TARGET} \
		--target_board board \
		${DG_TESTS} \
		GXX_UNDER_TEST=${DG_TARGET}-g++ ; \
	mv ${TMPDIR}/*.log ${TOPDIR} ; \
	mv ${TMPDIR}/*.sum ${TOPDIR}

clean:
	rm -rf gcc-testsuite-${DG_GCC_VERSION}.tar.gz gcc-${DG_GCC_VERSION} ${TMPDIR} *.log *.sum 

.PHONY: config test clean
