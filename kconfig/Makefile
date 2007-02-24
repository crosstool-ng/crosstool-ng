# ===========================================================================
# crosstool-ng configuration targets
# These targets are used from top-level makefile

KCONFIG_TOP = config/config.in
obj = ./kconfig
PHONY += clean help oldconfig menuconfig config silentoldconfig \
	randconfig allyesconfig allnoconfig allmodconfig defconfig

menuconfig: $(obj)/mconf
	@$< $(KCONFIG_TOP)

config: $(obj)/conf
	@$< $(KCONFIG_TOP)

oldconfig: $(obj)/conf
	@$< -s $(KCONFIG_TOP)

randconfig: $(obj)/conf
	@$< -r $(KCONFIG_TOP)

allyesconfig: $(obj)/conf
	@$< -y $(KCONFIG_TOP)

allnoconfig: $(obj)/conf
	@$< -n $(KCONFIG_TOP)

defconfig: $(obj)/conf
	@$< -d $(KCONFIG_TOP)

# Build a list of all available samples
SAMPLES = $(patsubst $(CT_TOP_DIR)/samples/%,%,$(filter-out %Makefile,$(wildcard $(CT_TOP_DIR)/samples/*)))
SAMPLES_CONFIG = $(patsubst %,%_config,$(SAMPLES))
.PHONY: $(SAMPLES_CONFIG)
$(SAMPLES_CONFIG):
	@cp "$(CT_TOP_DIR)/samples/$(patsubst %_config,%,$@)/crosstool.config" "$(CT_TOP_DIR)/.config"
	@$(MAKE) oldconfig

# Help text used by make help
help::
	@echo  'General purpose configuration targets:'
	@echo  '  config	  - Update current config utilising a line-oriented program'
	@echo  '  menuconfig	  - Update current config utilising a menu based program'
	@echo  '  oldconfig	  - Update current config utilising a provided .config as base'
	@echo  '  randconfig	  - New config with random answer to all options'
	@echo  '  defconfig	  - New config with default answer to all options'
	@echo  '  allyesconfig	  - New config where all options are accepted with yes'
	@echo  '  allnoconfig	  - New config where all options are answered with no'
	@echo
	@echo  'Preconfigured configuration targets:'
	@for s in $(SAMPLES_CONFIG); do   \
	    echo  "  $${s}"; \
	 done
	@echo  ''

# Cheesy build

SHIPPED = kconfig/zconf.tab.c kconfig/lex.zconf.c kconfig/zconf.hash.c

%.c: %.c_shipped
	@ln -s $(notdir $<) $@

kconfig/mconf: $(SHIPPED) kconfig/mconf.c
	@$(HOST_CC) -o $@ kconfig/{mconf.c,zconf.tab.c,lxdialog/*.c} \
		-lcurses "-DCURSES_LOC=<ncurses.h>"

kconfig/conf: $(SHIPPED) kconfig/conf.c
	@$(HOST_CC) -o $@ kconfig/{conf.c,zconf.tab.c}

clean::
	@rm -f $(wildcard kconfig/*zconf*.c) kconfig/{conf,mconf}
