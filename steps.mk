# Makefile for each steps
# Copyright 2006 Yann E. MORIN <yann.morin.1998@anciens.enib.fr>

CT_STEPS := libc_check_config   \
            kernel_check_config \
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
            tools               \
            debug               \

export CT_STEPS

$(CT_STEPS):
	@$(CT_NG) RESTART=$@ STOP=$@ build

$(patsubst %,+%,$(CT_STEPS)):
	@$(CT_NG) STOP=$(patsubst +%,%,$@) build

$(patsubst %,%+,$(CT_STEPS)):
	@$(CT_NG) RESTART=$(patsubst %+,%,$@) build

help-build::
	@echo  '  list-steps         - List all build steps'

list-steps:
	@echo  'Available build steps, in order:'
	@for step in $(CT_STEPS); do    \
	     echo "  - $${step}";       \
	 done
	@echo  'Use "$(CT_NG) <step>" to execute only that step.'
	@echo  'Use "$(CT_NG) +<step>" to execute up to that step.'
	@echo  'Use "$(CT_NG) <step>+" to execute from that step onward.'
