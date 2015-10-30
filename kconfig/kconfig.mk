# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

#-----------------------------------------------------------
# The configurators rules

configurators = menuconfig nconfig oldconfig savedefconfig defconfig
PHONY += $(configurators)

$(configurators): config_files

export CT_IS_A_BACKEND:=$(CT_IS_A_BACKEND)
export CT_BACKEND_ARCH:=$(CT_BACKEND_ARCH)
export CT_BACKEND_KERNEL:=$(CT_BACKEND_KERNEL)
export CT_BACKEND_LIBC:=$(CT_BACKEND_LIBC)

# We need CONF for savedefconfig in scripts/saveSample.sh
export CONF  := $(CT_LIB_DIR)/kconfig/conf
MCONF := $(CT_LIB_DIR)/kconfig/mconf
NCONF := $(CT_LIB_DIR)/kconfig/nconf

menuconfig:
	@$(CT_ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(MCONF) $(KCONFIG_TOP)

nconfig:
	@$(CT_ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(NCONF) $(KCONFIG_TOP)

oldconfig: .config
	@$(CT_ECHO) "  CONF  $(KCONFIG_TOP)"
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
