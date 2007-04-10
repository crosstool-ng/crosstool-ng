# Makefile for crosstool-NG.
# Copyright 2006 Yann E. MORIN <yann.morin.1998@anciens.enib.fr>

# The project version
export PROJECTVERSION=0.0.1

# This should eventually be computed if compiling out-of-tree is implemented
export CT_TOP_DIR=$(shell pwd)

.PHONY: all
all: _ct_build

HOST_CC = gcc -funsigned-char

help::
	@echo  'Available make targets (*: default target):'
	@echo

include $(CT_TOP_DIR)/kconfig/Makefile
#include $(CT_TOP_DIR)/samples/Makefile

help::
	@echo  'Build targets:'
	@echo  '* build          - Build the toolchain'
	@echo  '  clean          - Remove generated files'
	@echo  '  distclean      - Remove generated files, configuration and build directories'

include $(CT_TOP_DIR)/tools/Makefile

.config: config/*.in
	@make menuconfig
	@# Because exiting menuconfig without saving is not an error to menuconfig
	@test -f .config

# Actual build
_ct_build: .config
	@$(CT_TOP_DIR)/scripts/crosstool.sh

.PHONY: distclean
distclean:: clean
	@rm -f .config* ..config.tmp
	@rm -rf "$(CT_TOP_DIR)/build"
