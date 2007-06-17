# Makefile for crosstool-NG.
# Copyright 2006 Yann E. MORIN <yann.morin.1998@anciens.enib.fr>

# Don't print directory as we descend into them
MAKEFLAGS += --no-print-directory

export CT_TOP_DIR=$(shell pwd)

# This is crosstool-ng version string
export CT_VERSION=$(shell cat $(CT_TOP_DIR)/version)

export CT_STOP=$(STOP)
export CT_RESTART=$(RESTART)

.PHONY: all
all: build

HOST_CC = gcc -funsigned-char

help::
	@echo  'Available make targets:'
	@echo

include $(CT_TOP_DIR)/kconfig/Makefile
include $(CT_TOP_DIR)/samples/Makefile

help::
	@echo  'Build targets:'
	@echo  '* build          - Build the toolchain'
	@echo  '  regtest        - Regtest-build all samples'
	@echo  '  clean          - Remove generated files'
	@echo  '  distclean      - Remove generated files, configuration and build directories'

include $(CT_TOP_DIR)/tools/Makefile
include $(CT_TOP_DIR)/Makefile.steps

help::
	@echo  'Distribution targets:'
	@echo  '  tarball        - Build a tarball of the configured toolchain'
	@echo  ''
	@echo  'Environement variables (see docs/overview.txt):'
	@echo  '  STOP           - Stop the build just after this step'
	@echo  '  RESTART        - Restart the build just before this step'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*]'

.config:
	@echo "You must run either one of \"make config\" or \"make menuconfig\" first"
	@false

# Actual build
build: .config
	@$(CT_TOP_DIR)/scripts/crosstool.sh

.PHONY: tarball
tarball:
	@$(CT_TOP_DIR)/scripts/tarball.sh

.PHONY: distclean
distclean:: clean
	@rm -f .config* ..config.tmp
	@rm -f log.*
	@[ ! -d "$(CT_TOP_DIR)/targets" ] || chmod -R u+w "$(CT_TOP_DIR)/targets"
	@rm -rf "$(CT_TOP_DIR)/targets"
