# ===========================================================================
# crosstool-ng configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

KCONFIG_TOP = config/config.in
obj = ./kconfig
PHONY += clean help oldconfig menuconfig config silentoldconfig \
	randconfig allyesconfig allnoconfig allmodconfig defconfig

# Darwin (MacOS-X) does not have proper libintl support
ifeq ($(shell uname -s),Darwin)
KBUILD_NO_NLS:=1
endif

ifneq ($(KBUILD_NO_NLS),)
CFLAGS += -DKBUILD_NO_NLS
endif

# Build a list of all config files
CONFIG_FILES = $(filter-out %debug.in,$(shell find $(CT_TOP_DIR)/config -type f -name '*.in'))
DEBUG_CONFIG_FILES = $(shell find $(CT_TOP_DIR)/config/debug -type f -name '*.in')
TOOLS_CONFIG_FILES = $(shell find $(CT_TOP_DIR)/config/tools -type f -name '*.in')

GEN_CONFIG_FILES=$(CT_TOP_DIR)/config/debug.in	\
				 $(CT_TOP_DIR)/config/tools.in

$(CT_TOP_DIR)/config/debug.in: $(DEBUG_CONFIG_FILES)
	@echo "# Debug facilities menu" >$@
	@echo "# Generated file, do not edit!!!" >>$@
	@echo "menu \"Debug facilities\"" >>$@
	@for f in $(patsubst $(CT_TOP_DIR)/%,%,$(wildcard $(CT_TOP_DIR)/config/debug/*.in)); do \
	     echo "source $${f}";                                                               \
	 done >>$@
	@echo "endmenu" >>$@

$(CT_TOP_DIR)/config/tools.in: $(TOOLS_CONFIG_FILES)
	@echo "# Tools facilities menu" >$@
	@echo "# Generated file, do not edit!!!" >>$@
	@echo "menu \"Tools facilities\"" >>$@
	@for f in $(patsubst $(CT_TOP_DIR)/%,%,$(wildcard $(CT_TOP_DIR)/config/tools/*.in)); do \
	     echo "source $${f}";                                                               \
	 done >>$@
	@echo "endmenu" >>$@

menuconfig: $(obj)/mconf $(GEN_CONFIG_FILES)
	@$< $(KCONFIG_TOP)

config: $(obj)/conf $(GEN_CONFIG_FILES)
	@$< $(KCONFIG_TOP)

oldconfig: $(obj)/conf $(GEN_CONFIG_FILES)
	@$< -s $(KCONFIG_TOP)

defoldconfig:$(obj)/conf $(GEN_CONFIG_FILES)
	@$< -s $(KCONFIG_TOP) >/dev/null

# Help text used by make help
help::
	@echo  'General purpose configuration targets:'
	@echo  '  config         - Update current config using a line-oriented program'
	@echo  '  menuconfig     - Update current config using a menu based program'
	@echo  '  oldconfig      - Update current config using a provided .config as base'
	@# saveconfig is listed here for homogeneity, but implemented in samples/Makefile
	@echo  '  saveconfig     - Save current config as a preconfigured target'
	@echo  ''

# Cheesy build

SHIPPED = kconfig/zconf.tab.c kconfig/lex.zconf.c kconfig/zconf.hash.c

%.c: %.c_shipped
	@ln -s $(notdir $<) $@

kconfig/mconf: $(SHIPPED) kconfig/mconf.c
	@$(HOST_CC) $(CFLAGS) -o $@ kconfig/{mconf.c,zconf.tab.c,lxdialog/*.c} \
		-lcurses "-DCURSES_LOC=<ncurses.h>"

kconfig/conf: $(SHIPPED) kconfig/conf.c
	@$(HOST_CC) $(CFLAGS) -o $@ kconfig/{conf.c,zconf.tab.c}

clean::
	@rm -f $(wildcard kconfig/*zconf*.c) kconfig/{conf,mconf}
	@rm -f $(GEN_CONFIG_FILES)
