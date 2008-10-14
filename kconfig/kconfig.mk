# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

#-----------------------------------------------------------
# Some static /configuration/

KCONFIG_TOP = config/config.in
obj = kconfig
PHONY += clean help oldconfig menuconfig defoldconfig

# Darwin (MacOS-X) does not have proper libintl support
ifeq ($(shell uname -s),Darwin)
KBUILD_NO_NLS:=1
endif

ifneq ($(KBUILD_NO_NLS),)
CFLAGS += -DKBUILD_NO_NLS
endif

#-----------------------------------------------------------
# List all config files, source and generated

# Build the list of all source config files
STATIC_CONFIG_FILES = $(patsubst $(CT_LIB_DIR)/%,%,$(shell find $(CT_LIB_DIR)/config -type f -name '*.in' 2>/dev/null))
# ... and how to access them:
$(STATIC_CONFIG_FILES): config

# Build a list of per-component-type source config files
ARCH_CONFIG_FILES   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/arch/*.in))
KERNEL_CONFIG_FILES = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/kernel/*.in))
CC_CONFIG_FILES     = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/cc/*.in))
LIBC_CONFIG_FILES   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/libc/*.in))
DEBUG_CONFIG_FILES  = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/debug/*.in))
TOOL_CONFIG_FILES   = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/config/tools/*.in))

# Build the list of generated config files
GEN_CONFIG_FILES = config.gen/arch.in     \
                   config.gen/kernel.in   \
                   config.gen/cc.in       \
                   config.gen/libc.in     \
                   config.gen/tools.in    \
                   config.gen/debug.in
# ... and how to access them:
# Generated files depends on kconfig.mk (this file) because it has the
# functions needed to build the genrated files, and thus they might
# need re-generation if kconfig.mk changes
$(GEN_CONFIG_FILES): config.gen                         \
                     $(CT_LIB_DIR)/kconfig/kconfig.mk

# KCONFIG_TOP should already be in STATIC_CONFIG_FILES, anyway...
CONFIG_FILES = $(sort $(KCONFIG_TOP) $(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES))

# Where to access to the source config files from
config:
	@echo "  LN    config"
	@ln -s $(CT_LIB_DIR)/config config

# Where to store the generated config files into
config.gen:
	@echo "  MKDIR config.gen"
	@mkdir -p config.gen

#-----------------------------------------------------------
# Build list of per-component-type items to easily build generated files

ARCHS   = $(patsubst config/arch/%.in,%,$(ARCH_CONFIG_FILES))
KERNELS = $(patsubst config/kernel/%.in,%,$(KERNEL_CONFIG_FILES))
CCS     = $(patsubst config/cc/%.in,%,$(CC_CONFIG_FILES))
LIBCS   = $(patsubst config/libc/%.in,%,$(LIBC_CONFIG_FILES))
DEBUGS  = $(patsubst config/debug/%.in,%,$(DEBUG_CONFIG_FILES))
TOOLS   = $(patsubst config/tools/%.in,%,$(TOOL_CONFIG_FILES))

#-----------------------------------------------------------
# Helper functions to ease building generated config files

# The function 'build_gen_choice_in' builds a choice-menu of a list of
# components in the given list, also adding source-ing of associazted
# config files:
# $1 : destination file
# $2 : name for the entries family (eg. Architecture, kernel...)
# $3 : prefix for the choice entries (eg. ARCH, KERNEL...)
# $4 : base directory containing config files
# $5 : list of config entries (eg. for architectures: "alpha arm ia64"...,
#      and for kernels: "bare-metal linux"...)
# Example to build the kernels generated config file:
# $(call build_gen_choice_in,config.gen/kernel.in,Target OS,KERNEL,config/kernel,$(KERNELS))
define build_gen_choice_in
	@echo '  IN    $(1)'
	@(echo "# $(2) menu";                                               \
	  echo "# Generated file, do not edit!!!";                          \
	  echo "";                                                          \
	  echo "choice";                                                    \
	  echo "    bool";                                                  \
	  echo "    prompt \"$(2)\"";                                       \
	  echo "";                                                          \
	  for entry in $(5); do                                             \
	    file="$(4)/$${entry}.in";                                       \
	    _entry=$$(echo "$${entry}" |sed -r -s -e 's/[-.+]/_/g;');       \
	    echo "config $(3)_$${_entry}";                                  \
	    echo "    bool";                                                \
	    printf "    prompt \"$${entry}";                                \
	    if grep -E '^# +EXPERIMENTAL$$' $${file} >/dev/null 2>&1; then  \
	      echo " (EXPERIMENTAL)\"";                                     \
	      echo "    depends on EXPERIMENTAL";                           \
	    else                                                            \
	      echo "\"";                                                    \
	    fi;                                                             \
	  done;                                                             \
	  echo "";                                                          \
	  echo "endchoice";                                                 \
	  for entry in $(5); do                                             \
	    file="$(4)/$${entry}.in";                                       \
	    _entry=$$(echo "$${entry}" |sed -r -s -e 's/[-.+]/_/g;');       \
	    echo "";                                                        \
	    echo "if $(3)_$${_entry}";                                      \
	    echo "config $(3)";                                             \
	    echo "    default \"$${entry}\" if $(3)_$${_entry}";            \
	    echo "source $${file}";                                         \
	    echo "endif";                                                   \
	  done;                                                             \
	 ) >$(1)
endef

# The function 'build_gen_menu_in' builds a menuconfig for each component in
# the given list, source-ing the associated files conditionnaly:
# $1 : destination file
# $2 : name of entries family (eg. Tools, Debug...)
# $3 : prefix for the menu entries (eg. TOOL, DEBUG)
# $4 : base directory containing config files
# $5 : list of config entries (eg. for tools: "libelf sstrip"..., and for
#      debug: "dmalloc duma gdb"...)
# Example to build the tools generated config file:
# $(call build_gen_menu_in,config.gen/tools.in,Tools,TOOL,config/tools,$(TOOLS))
define build_gen_menu_in
	@echo '  IN    $(1)'
	@(echo "# $(2) facilities menu";                                    \
	  echo "# Generated file, do not edit!!!";                          \
	  echo "";                                                          \
	  for entry in $(5); do                                             \
	    file="$(4)/$${entry}.in";                                       \
	    _entry=$$(echo "$${entry}" |sed -r -s -e 's/[-.+]/_/g;');       \
	    echo "menuconfig $(3)_$${_entry}";                              \
	    echo "    bool";                                                \
	    printf "    prompt \"$${entry}";                                \
	    if grep -E '^# +EXPERIMENTAL$$' $${file} >/dev/null 2>&1; then  \
	      echo " (EXPERIMENTAL)\"";                                     \
	      echo "    depends on EXPERIMENTAL";                           \
	    else                                                            \
	      echo "\"";                                                    \
	    fi;                                                             \
	    echo "if $(3)_$${_entry}";                                      \
	    echo "source $${file}";                                         \
	    echo "endif";                                                   \
	    echo "";                                                        \
	  done;                                                             \
	 ) >$(1)
endef

#-----------------------------------------------------------
# The rules for the generated config files

config.gen/arch.in: $(ARCH_CONFIG_FILES)
	$(call build_gen_choice_in,$@,Target Architecture,ARCH,config/arch,$(ARCHS))

config.gen/kernel.in: $(KERNEL_CONFIG_FILES)
	$(call build_gen_choice_in,$@,Target OS,KERNEL,config/kernel,$(KERNELS))

config.gen/cc.in: $(CC_CONFIG_FILES)
	$(call build_gen_choice_in,$@,C compiler,CC,config/cc,$(CCS))

config.gen/libc.in: $(LIBC_CONFIG_FILES)
	$(call build_gen_choice_in,$@,C library,LIBC,config/libc,$(LIBCS))

config.gen/tools.in: $(TOOL_CONFIG_FILES)
	$(call build_gen_menu_in,$@,Tools,TOOL,config/tools,$(TOOLS))

config.gen/debug.in: $(DEBUG_CONFIG_FILES)
	$(call build_gen_menu_in,$@,Debug,DEBUG,config/debug,$(DEBUGS))

#-----------------------------------------------------------
# The configurators rules

menuconfig: $(CONFIG_FILES) $(obj)/mconf
	@$(obj)/mconf $(KCONFIG_TOP)

oldconfig: $(CONFIG_FILES) $(obj)/conf
	@$(obj)/conf -s $(KCONFIG_TOP)

defoldconfig: $(CONFIG_FILES) $(obj)/conf
	@yes "" |$(obj)/conf -s $(KCONFIG_TOP)

#-----------------------------------------------------------
# Help text used by make help

help-config::
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '                       build log piped into stdin'

#-----------------------------------------------------------
# Not-so-cheesy build, needs rework...

SHIPPED := $(CT_LIB_DIR)/kconfig/zconf.tab.c $(CT_LIB_DIR)/kconfig/lex.zconf.c $(CT_LIB_DIR)/kconfig/zconf.hash.c

$(obj)/conf $(obj)/mconf: $(obj)

$(obj):
	@mkdir -p $(obj)

HEADERS = $(CT_LIB_DIR)/kconfig/expr.h      \
          $(CT_LIB_DIR)/kconfig/lkc.h       \
          $(CT_LIB_DIR)/kconfig/lkc_proto.h

FILES = $(CT_LIB_DIR)/kconfig/confdata.c    \
        $(CT_LIB_DIR)/kconfig/expr.c        \
        $(CT_LIB_DIR)/kconfig/menu.c        \
        $(CT_LIB_DIR)/kconfig/symbol.c      \
        $(CT_LIB_DIR)/kconfig/util.c

$(obj)/mconf: $(SHIPPED) $(CT_LIB_DIR)/kconfig/mconf.c  \
              $(HEADERS) $(FILES)                       \
              $(CT_LIB_DIR)/kconfig/kconfig.mk
	@echo '  LD    $@'
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{mconf.c,zconf.tab.c,lxdialog/*.c} \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ccflags)              \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ldflags $(HOST_CC))

$(obj)/conf: $(SHIPPED) $(CT_LIB_DIR)/kconfig/conf.c    \
             $(HEADERS) $(FILES)                        \
             $(CT_LIB_DIR)/kconfig/kconfig.mk
	@echo '  LD    $@'
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{conf.c,zconf.tab.c}

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@echo "  CLEAN kconfig"
	@rm -f kconfig/{,m}conf
	@rmdir --ignore-fail-on-non-empty kconfig 2>/dev/null || true
	@echo "  CLEAN config"
	@rm -f config 2>/dev/null || true
	@echo "  CLEAN config.gen"
	@rm -rf config.gen
