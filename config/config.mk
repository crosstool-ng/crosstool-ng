# ===========================================================================
# crosstool-NG genererated config files
# These targets are used from top-level makefile

#-----------------------------------------------------------
# List all config files, wether sourced or generated

# The top-level config file to be used be configurators
KCONFIG_TOP = config/config.in

# Build the list of all source config files
STATIC_CONFIG_FILES = $(patsubst $(CT_LIB_DIR)/%,%,$(shell find $(CT_LIB_DIR)/config -type f \( -name '*.in' -o -name '*.in.2' \) 2>/dev/null))
# ... and how to access them:
$(STATIC_CONFIG_FILES): config

# Build a list of per-component-type source config files
ARCH_CONFIG_FILES     = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/arch/*.in))
ARCH_CONFIG_FILES_2   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/arch/*.in.2))
KERNEL_CONFIG_FILES   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/kernel/*.in))
KERNEL_CONFIG_FILES_2 = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/kernel/*.in.2))
CC_CONFIG_FILES       = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/cc/*.in))
CC_CONFIG_FILES_2     = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/cc/*.in.2))
LIBC_CONFIG_FILES     = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/libc/*.in))
LIBC_CONFIG_FILES_2   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/libc/*.in.2))
DEBUG_CONFIG_FILES    = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/debug/*.in))

# Build the list of generated config files
GEN_CONFIG_FILES = config.gen/arch.in     \
                   config.gen/kernel.in   \
                   config.gen/cc.in       \
                   config.gen/libc.in     \
                   config.gen/debug.in
# ... and how to access them:
# Generated files depends on config.mk (this file) because it has the
# functions needed to build the genrated files, and thus they might
# need re-generation if config.mk changes
$(GEN_CONFIG_FILES): config.gen                         \
                     $(CT_LIB_DIR)/config/config.mk

# Helper entry for the configurators
PHONY += config_files
config_files: $(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

# Where to access to the source config files from
config:
	@$(ECHO) "  LN    config"
	$(SILENT)ln -s $(CT_LIB_DIR)/config config

# Where to store the generated config files into
config.gen:
	@$(ECHO) "  MKDIR config.gen"
	$(SILENT)mkdir -p config.gen

#-----------------------------------------------------------
# Build list of per-component-type items to easily build generated files

ARCHS   = $(patsubst config/arch/%.in,%,$(ARCH_CONFIG_FILES))
KERNELS = $(patsubst config/kernel/%.in,%,$(KERNEL_CONFIG_FILES))
CCS     = $(patsubst config/cc/%.in,%,$(CC_CONFIG_FILES))
LIBCS   = $(patsubst config/libc/%.in,%,$(LIBC_CONFIG_FILES))
DEBUGS  = $(patsubst config/debug/%.in,%,$(DEBUG_CONFIG_FILES))

#-----------------------------------------------------------
# Helper functions to ease building generated config files

# The function 'build_gen_choice_in' builds a choice-menu of a list of
# components in the given list, also adding source-ing of associazted
# config files:
# $1 : destination file
# $2 : name for the entries family (eg. Architecture, kernel...)
# $3 : prefix for the choice entries (eg. ARCH, KERNEL...)
# $4 : base directory containing config files
# $5 : generate backend conditionals if Y, don't if anything else
# $6 : list of config entries (eg. for architectures: "alpha arm ia64"...,
#      and for kernels: "bare-metal linux"...)
# Example to build the kernels generated config file:
# $(call build_gen_choice_in,config.gen/kernel.in,Target OS,KERNEL,config/kernel,$(KERNELS))
define build_gen_choice_in
	@$(ECHO) '  IN    $(1)'
	$(SILENT)(echo "# $(2) menu";                                           \
	  echo "# Generated file, do not edit!!!";                              \
	  echo "";                                                              \
	  echo "choice GEN_CHOICE_$(3)";                                        \
	  echo "    bool";                                                      \
	  echo "    prompt \"$(2)\"";                                           \
	  echo "";                                                              \
	  for entry in $(6); do                                                 \
	    file="$(4)/$${entry}.in";                                           \
	    _entry=$$(echo "$${entry}" |$(sed) -r -s -e 's/[-.+]/_/g;');        \
	    echo "config $(3)_$${_entry}";                                      \
	    echo "    bool";                                                    \
	    echo "    prompt \"$${entry}\"";                                    \
	    if [ "$(5)" = "Y" ]; then                                           \
	      echo "    depends on $(3)_$${_entry}_AVAILABLE";                  \
	    fi;                                                                 \
	    sed -r -e '/^## depends on /!d; s/^## /    /;' $${file} 2>/dev/null;\
	    sed -r -e '/^## select /!d; s/^## /    /;' $${file} 2>/dev/null;    \
		echo "    help";                                                    \
	    sed -r -e '/^## help ?/!d; s/^## help ?/      /;' $${file} 2>/dev/null; \
	    echo "";                                                            \
	  done;                                                                 \
	  echo "endchoice";                                                     \
	  for entry in $(6); do                                                 \
	    file="$(4)/$${entry}.in";                                           \
	    _entry=$$(echo "$${entry}" |$(sed) -r -s -e 's/[-.+]/_/g;');        \
	    echo "";                                                            \
	    if [ "$(5)" = "Y" ]; then                                                                           \
	      echo "config $(3)_$${_entry}_AVAILABLE";                                                          \
	      echo "    bool";                                                                                  \
	      echo "    default n if ! ( BACKEND_$(3) = \"$${entry}\" || BACKEND_$(3) = \"\" || ! BACKEND )";   \
	      echo "    default y if BACKEND_$(3) = \"$${entry}\" || BACKEND_$(3) = \"\" || ! BACKEND";         \
	    fi;                                                                                                 \
	    echo "if $(3)_$${_entry}";                                          \
	    echo "config $(3)";                                                 \
	    echo "    default \"$${entry}\" if $(3)_$${_entry}";                \
	    echo "source \"$${file}\"";                                         \
	    echo "endif";                                                       \
	  done;                                                                 \
	  echo "";                                                              \
	  for file in $(wildcard $(4)/*.in-common); do                          \
	    echo "source \"$${file}\"";                                         \
	  done;                                                                 \
	 ) >$(1)
	$(SILENT)(echo "# $(2) second part options";                            \
	  echo "# Generated file, do not edit!!!";                              \
	  for entry in $(6); do                                                 \
	    file="$(4)/$${entry}.in";                                           \
	    _entry=$$(echo "$${entry}" |$(sed) -r -s -e 's/[-.+]/_/g;');        \
	    if [ -f "$${file}.2" ]; then                                        \
	      echo "";                                                          \
	      echo "if $(3)_$${_entry}";                                        \
	      echo "comment \"$${entry} other options\"";                       \
	      echo "source \"$${file}.2\"";                                     \
	      echo "endif";                                                     \
	    fi;                                                                 \
	  done;                                                                 \
	 ) >$(1).2
endef

# The function 'build_gen_menu_in' builds a menuconfig for each component in
# the given list, source-ing the associated files conditionnaly:
# $1 : destination file
# $2 : name of entries family (eg. Tools, Debug...)
# $3 : prefix for the menu entries (eg. DEBUG)
# $4 : base directory containing config files
# $5 : list of config entries (eg. for debug: "dmalloc duma gdb"...)
# Example to build the generated debug config file:
# $(call build_gen_menu_in,config.gen/debug.in,Debug,DEBUG,config/debug,$(DEBUGS))
define build_gen_menu_in
	@$(ECHO) '  IN    $(1)'
	$(SILENT)(echo "# $(2) facilities menu";                                \
	  echo "# Generated file, do not edit!!!";                              \
	  echo "";                                                              \
	  for entry in $(5); do                                                 \
	    file="$(4)/$${entry}.in";                                           \
	    _entry=$$(echo "$${entry}" |$(sed) -r -s -e 's/[-.+]/_/g;');        \
	    echo "menuconfig $(3)_$${_entry}";                                  \
	    echo "    bool";                                                    \
	    echo "    prompt \"$${entry}\"";                                    \
	    sed -r -e '/^## depends on /!d; s/^## /    /;' $${file} 2>/dev/null;\
	    sed -r -e '/^## select /!d; s/^## /    /;' $${file} 2>/dev/null;    \
		echo "    help";                                                    \
	    sed -r -e '/^## help ?/!d; s/^## help ?/      /;' $${file} 2>/dev/null; \
	    echo "";                                                            \
	    echo "if $(3)_$${_entry}";                                          \
	    echo "source \"$${file}\"";                                         \
	    echo "endif";                                                       \
	    echo "";                                                            \
	  done;                                                                 \
	 ) >$(1)
endef

#-----------------------------------------------------------
# The rules for the generated config files

# WARNING! If a .in file disapears between two runs, that will NOT be detected!

config.gen/arch.in: $(ARCH_CONFIG_FILES) $(ARCH_CONFIG_FILES_2)
	$(call build_gen_choice_in,$@,Target Architecture,ARCH,config/arch,Y,$(ARCHS))

config.gen/kernel.in: $(KERNEL_CONFIG_FILES) $(KERNEL_CONFIG_FILES_2)
	$(call build_gen_choice_in,$@,Target OS,KERNEL,config/kernel,Y,$(KERNELS))

config.gen/cc.in: $(CC_CONFIG_FILES) $(CC_CONFIG_FILES_2)
	$(call build_gen_choice_in,$@,C compiler,CC,config/cc,,$(CCS))

config.gen/libc.in: $(LIBC_CONFIG_FILES) $(LIBC_CONFIG_FILES_2)
	$(call build_gen_choice_in,$@,C library,LIBC,config/libc,Y,$(LIBCS))

config.gen/debug.in: $(DEBUG_CONFIG_FILES)
	$(call build_gen_menu_in,$@,Debug,DEBUG,config/debug,$(DEBUGS))

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@$(ECHO) "  CLEAN config"
	$(SILENT)rm -f config 2>/dev/null || true
	@$(ECHO) "  CLEAN config.gen"
	$(SILENT)rm -rf config.gen
