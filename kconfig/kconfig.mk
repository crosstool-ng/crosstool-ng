# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

#-----------------------------------------------------------
# The configurators rules

configurators = menuconfig nconfig oldconfig
PHONY += $(configurators)

$(configurators): config_files

CONF  := $(CT_LIB_DIR)/kconfig/conf
MCONF := $(CT_LIB_DIR)/kconfig/mconf
NCONF := $(CT_LIB_DIR)/kconfig/nconf

menuconfig:
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(MCONF) $(KCONFIG_TOP)

nconfig:
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(NCONF) $(KCONFIG_TOP)

oldconfig: .config
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(CONF) --silent$@ $(KCONFIG_TOP)

# Always be silent, the stdout an be >.config
extractconfig:
	@awk 'BEGIN { dump=0; }                                                 \
	      dump==1 && $$0~/^\[.....\][[:space:]]+(# |)CT_/ {                 \
	          $$1="";                                                       \
	          gsub("^[[:space:]]","");                                      \
	          print;                                                        \
	      }                                                                 \
	      $$0~/Dumping user-supplied crosstool-NG configuration: done in/ { \
	          dump=0;                                                       \
	      }                                                                 \
	      $$0~/Dumping user-supplied crosstool-NG configuration$$/ {        \
	          dump=1;                                                       \
	      }'

#-----------------------------------------------------------
# Help text used by make help

help-config::
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '  extractconfig      - Extract to stdout the configuration items from a'
	@echo  '                       build.log file piped to stdin'
