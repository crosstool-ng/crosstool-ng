# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

#-----------------------------------------------------------
# The configurators rules

# Top file of crosstool-NG configuration
export KCONFIG_TOP = $(CT_LIB_DIR)/config/config.in

# We need CONF for savedefconfig in scripts/saveSample.sh
export CONF  := $(CT_LIB_DIR)/kconfig/conf
MCONF := $(CT_LIB_DIR)/kconfig/mconf
NCONF := $(CT_LIB_DIR)/kconfig/nconf

# Used by conf/mconf/nconf to find the .in files
export srctree=$(CT_LIB_DIR)

menuconfig:
	@$(CT_ECHO) "  CONF  $@"
	$(SILENT)$(MCONF) $(KCONFIG_TOP)

nconfig:
	@$(CT_ECHO) "  CONF  $@"
	$(SILENT)$(NCONF) $(KCONFIG_TOP)

oldconfig: .config
	@$(CT_ECHO) "  CONF  $@"
	$(SILENT)$(sed) -i -r -f $(CT_LIB_DIR)/scripts/upgrade.sed $<
	$(SILENT)$(CONF) --silent$@ $(KCONFIG_TOP)

savedefconfig: .config
	@$(CT_ECHO) '  GEN   $@'
	$(SILENT)$(CONF) --savedefconfig=$${DEFCONFIG-defconfig} $(KCONFIG_TOP)

defconfig:
	@$(CT_ECHO) '  CONF  $@'
	$(SILENT)$(CONF) --defconfig=$${DEFCONFIG-defconfig} $(KCONFIG_TOP)

# Always be silent, the stdout an be >.config
extractconfig:
	@$(awk) 'BEGIN { dump=0; }                                                  \
	         dump==1 && $$0~/^\[.....\][[:space:]]+(# )?CT_/ {                  \
	             $$1="";                                                        \
	             gsub("^[[:space:]]","");                                       \
	             print;                                                         \
	         }                                                                  \
	         $$0~/Dumping user-supplied crosstool-NG configuration: done in/ {  \
	             dump=0;                                                        \
	         }                                                                  \
	         $$0~/Dumping user-supplied crosstool-NG configuration$$/ {         \
	             dump=1;                                                        \
	         }'

#-----------------------------------------------------------
# Help text used by make help

help-config::
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  nconfig            - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '  extractconfig      - Extract to stdout the configuration items from a'
	@echo  '                       build.log file piped to stdin'
	@echo  '  savedefconfig      - Save current config as a mini-defconfig to $${DEFCONFIG}'
	@echo  '  defconfig          - Update config from a mini-defconfig $${DEFCONFIG}'
	@echo  '                       (default: $${DEFCONFIG}=./defconfig)'
