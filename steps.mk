# Makefile for each steps
# Copyright 2006 Yann E. MORIN <yann.morin.1998@anciens.enib.fr>

# ----------------------------------------------------------
# This is the steps help entry

help-build::
	@echo  '  list-steps         - List all build steps'

# ----------------------------------------------------------
# The steps list

# Please keep the last line with a '\' and keep the folowing empy line:
# it helps when diffing and merging.
CT_STEPS := libc_check_config   \
            kernel_headers      \
            gmp                 \
            mpfr                \
            binutils            \
            cc_core_pass_1      \
            libc_headers        \
            libc_start_files    \
            cc_core_pass_2      \
            libc                \
            cc                  \
            libc_finish         \
            binutils_target     \
            gmp_target          \
            mpfr_target         \
            tools               \
            debug               \

# Make the list available to sub-processes (scripts/crosstool.sh needs it)
export CT_STEPS

# Print the steps list
PHONY += list-steps
list-steps:
	@echo  'Available build steps, in order:'
	@for step in $(CT_STEPS); do    \
	     echo "  - $${step}";       \
	 done
	@echo  'Use "<step>" as action to execute only that step.'
	@echo  'Use "+<step>" as action to execute up to that step.'
	@echo  'Use "<step>+" as action to execute from that step onward.'

# ----------------------------------------------------------
# This part deals with executing steps

$(CT_STEPS):
	$(SILENT)$(MAKE) -rf $(CT_NG) V=$(V) RESTART=$@ STOP=$@ build

$(patsubst %,+%,$(CT_STEPS)):
	$(SILENT)$(MAKE) -rf $(CT_NG) V=$(V) STOP=$(patsubst +%,%,$@) build

$(patsubst %,%+,$(CT_STEPS)):
	$(SILENT)$(MAKE) -rf $(CT_NG) V=$(V) RESTART=$(patsubst %+,%,$@) build
