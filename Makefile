# Makefile for crosstool-NG.
# Copyright 2006 Yann E. MORIN <yann.morin.1998@anciens.enib.fr>

# Don't print directory as we descend into them
MAKEFLAGS += --no-print-directory

# The project version
export PROJECTVERSION=0.0.2-svn

# This should eventually be computed if compiling out-of-tree is implemented
export CT_TOP_DIR=$(shell pwd)

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
	@echo  '  tarball        - Build a tarball of the configured toolchain'
	@echo  '  clean          - Remove generated files'
	@echo  '  distclean      - Remove generated files, configuration and build directories'

include $(CT_TOP_DIR)/tools/Makefile

help::
	@echo  'Execute "make" or "make all" to build all targets marked with [*]'

.config: $(shell find $(CT_TOP_DIR)/config -type f -name '*.in')
	@make menuconfig
	@# Because exiting menuconfig without saving is not an error to menuconfig
	@test -f .config

# Actual build
build: .config
	@$(CT_TOP_DIR)/scripts/crosstool.sh

.PHONY: tarball
tarball:
	@$(CT_TOP_DIR)/scripts/tarball.sh

.PHONY: distclean
distclean:: clean
	@rm -f .config* ..config.tmp
	@rm -rf "$(CT_TOP_DIR)/targets"
