# ===========================================================================
# crosstool-NG genererated config files
# These targets are used from top-level makefile

#-----------------------------------------------------------
# List all config files, wether sourced or generated

# The top-level config file to be used be configurators
# We need it to savedefconfig in scripts/saveSample.sh
export KCONFIG_TOP = config/config.in

# Build the list of all source config files
STATIC_CONFIG_FILES = $(patsubst $(CT_LIB_DIR)/%,%,$(shell find $(CT_LIB_DIR)/config -type f \( -name '*.in' -o -name '*.in.2' \) 2>/dev/null))
# ... and how to access them:
$(STATIC_CONFIG_FILES): config

# Build a list of per-component-type source config files
ARCH_CONFIG_FILES       = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/arch/*.in)))
ARCH_CONFIG_FILES_2     = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/arch/*.in.2)))
KERNEL_CONFIG_FILES     = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/kernel/*.in)))
KERNEL_CONFIG_FILES_2   = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/kernel/*.in.2)))
CC_CONFIG_FILES         = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/cc/*.in)))
CC_CONFIG_FILES_2       = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/cc/*.in.2)))
BINUTILS_CONFIG_FILES   = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/binutils/*.in)))
BINUTILS_CONFIG_FILES_2 = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/binutils/*.in.2)))
LIBC_CONFIG_FILES       = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/libc/*.in)))
LIBC_CONFIG_FILES_2     = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/libc/*.in.2)))
DEBUG_CONFIG_FILES      = $(patsubst $(CT_LIB_DIR)/%,%,$(sort $(wildcard $(CT_LIB_DIR)/config/debug/*.in)))

# Build the list of generated config files
GEN_CONFIG_FILES = config.gen/arch.in     \
                   config.gen/kernel.in   \
                   config.gen/cc.in       \
                   config.gen/binutils.in \
                   config.gen/libc.in     \
                   config.gen/debug.in
# ... and how to access them:
# Generated files depends on the gen_in_frags script because it has the
# functions needed to build the genrated files, and thus they might need
# re-generation if it changes.
# They also depends on config.mk (this file) because it has the dependency
# rules, and thus they might need re-generation if the deps change.
$(GEN_CONFIG_FILES): config.gen                             \
                     $(CT_LIB_DIR)/scripts/gen_in_frags.sh  \
                     $(CT_LIB_DIR)/config/config.mk

# Helper entry for the configurators
PHONY += config_files
config_files: $(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

# Where to access to the source config files from
config:
	@$(CT_ECHO) "  LN    config"
	$(SILENT)ln -s $(CT_LIB_DIR)/config config

# Where to store the generated config files into
config.gen:
	@$(CT_ECHO) "  MKDIR config.gen"
	$(SILENT)mkdir -p config.gen

#-----------------------------------------------------------
# Build list of per-component-type items to easily build generated files

ARCHS     = $(patsubst config/arch/%.in,%,$(ARCH_CONFIG_FILES))
KERNELS   = $(patsubst config/kernel/%.in,%,$(KERNEL_CONFIG_FILES))
CCS       = $(patsubst config/cc/%.in,%,$(CC_CONFIG_FILES))
BINUTILSS = $(patsubst config/binutils/%.in,%,$(BINUTILS_CONFIG_FILES))
LIBCS     = $(patsubst config/libc/%.in,%,$(LIBC_CONFIG_FILES))
DEBUGS    = $(patsubst config/debug/%.in,%,$(DEBUG_CONFIG_FILES))

#-----------------------------------------------------------
# The rules for the generated config files

# WARNING! If a .in file disapears between two runs, that will NOT be detected!

config.gen/arch.in: $(ARCH_CONFIG_FILES) $(ARCH_CONFIG_FILES_2)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh choice "$@" "Target Architecture" "ARCH" "config/arch" "Y" $(ARCHS)

config.gen/kernel.in: $(KERNEL_CONFIG_FILES) $(KERNEL_CONFIG_FILES_2)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh choice "$@" "Target OS" "KERNEL" "config/kernel" "Y" $(KERNELS)

config.gen/cc.in: $(CC_CONFIG_FILES) $(CC_CONFIG_FILES_2)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh choice "$@" "C compiler" "CC" "config/cc" "N" $(CCS)

config.gen/binutils.in: $(CC_BINUTILS_FILES) $(CC_BINUTILS_FILES_2)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh choice "$@" "Binutils" "BINUTILS" "config/binutils" "N" $(BINUTILSS)

config.gen/libc.in: $(LIBC_CONFIG_FILES) $(LIBC_CONFIG_FILES_2)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh choice "$@" "C library" "LIBC" "config/libc" "Y" $(LIBCS)

config.gen/debug.in: $(DEBUG_CONFIG_FILES)
	@$(CT_ECHO) '  IN    $(@)'
	$(SILENT)$(CT_LIB_DIR)/scripts/gen_in_frags.sh menu "$@" "Debug facilities" "DEBUG" "config/debug" $(DEBUGS)

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@$(CT_ECHO) "  CLEAN config"
	$(SILENT)rm -f config 2>/dev/null || true
	@$(CT_ECHO) "  CLEAN config.gen"
	$(SILENT)rm -rf config.gen
