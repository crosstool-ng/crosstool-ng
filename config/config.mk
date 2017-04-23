#-----------------------------------------------------------
# List all config files

# The top-level config file to be used be configurators
# We need it to savedefconfig in scripts/saveSample.sh
export KCONFIG_TOP = config/config.in

# Build the list of all source config files
STATIC_CONFIG_FILES = $(patsubst $(CT_LIB_DIR)/%,%,$(shell find $(CT_LIB_DIR)/config -type f \( -name '*.in' -o -name '*.in.2' \) 2>/dev/null))
# ... and how to access them:
$(STATIC_CONFIG_FILES): config

# Helper entry for the configurators
PHONY += config_files
config_files: $(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

# Where to access to the source config files from
config:
	@$(CT_ECHO) "  LN    config"
	$(SILENT)ln -s $(CT_LIB_DIR)/config config

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@$(CT_ECHO) "  CLEAN config"
	$(SILENT)rm -f config 2>/dev/null || true
