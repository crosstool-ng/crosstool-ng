# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

KCONFIG_TOP = config/config.in
obj = $(CT_TOP_DIR)/kconfig
PHONY += clean help oldconfig menuconfig config defoldconfig

# Darwin (MacOS-X) does not have proper libintl support
ifeq ($(shell uname -s),Darwin)
KBUILD_NO_NLS:=1
endif

ifneq ($(KBUILD_NO_NLS),)
CFLAGS += -DKBUILD_NO_NLS
endif

# Build a list of all config files
ARCH_CONFIG_FILES   = $(wildcard $(CT_LIB_DIR)/config/arch/*.in)
KERNEL_CONFIG_FILES = $(wildcard $(CT_LIB_DIR)/config/kernel/*.in)
LIBC_CONFIG_FILES   = $(wildcard $(CT_LIB_DIR)/config/libc/*.in)
DEBUG_CONFIG_FILES  = $(wildcard $(CT_LIB_DIR)/config/debug/*.in)
TOOL_CONFIG_FILES   = $(wildcard $(CT_LIB_DIR)/config/tools/*.in)

STATIC_CONFIG_FILES = $(shell find $(CT_LIB_DIR)/config -type f -name '*.in')
GEN_CONFIG_FILES=$(CT_TOP_DIR)/config.gen/arch.in   \
                 $(CT_TOP_DIR)/config.gen/kernel.in \
                 $(CT_TOP_DIR)/config.gen/libc.in   \
                 $(CT_TOP_DIR)/config.gen/tools.in  \
                 $(CT_TOP_DIR)/config.gen/debug.in

CONFIG_FILES=$(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

# Build list of items
ARCHS   = $(patsubst $(CT_LIB_DIR)/config/arch/%.in,%,$(ARCH_CONFIG_FILES))
KERNELS = $(patsubst $(CT_LIB_DIR)/config/kernel/%.in,%,$(KERNEL_CONFIG_FILES))
LIBCS   = $(patsubst $(CT_LIB_DIR)/config/libc/%.in,%,$(LIBC_CONFIG_FILES))
DEBUGS  = $(patsubst $(CT_LIB_DIR)/config/debug/%.in,%,$(DEBUG_CONFIG_FILES))
TOOLS   = $(patsubst $(CT_LIB_DIR)/config/tools/%.in,%,$(TOOL_CONFIG_FILES))

$(GEN_CONFIG_FILES): $(CT_TOP_DIR)/config.gen           \
                     $(CT_LIB_DIR)/kconfig/kconfig.mk

$(CT_TOP_DIR)/config.gen: $(KCONFIG_TOP)
	@mkdir -p $(CT_TOP_DIR)/config.gen

# Function build_gen_choice_in:
# $1 : destination file
# $2 : name for the entries family (eg. Architecture, kernel...)
# $3 : prefix for the choice entries (eg. ARCH, KERNEL...)
# $4 : base directory containing config files
# $5 : list of config entries (eg. for architectures: "alpha arm ia64"...,
#      and for kernels: "bare-metal linux"...)
# Example to build the kernels generated config file:
# $(call build_gen_choice_in,config.gen/kernel.in,Target OS,KERNEL,config/kernel,$(KERNELS))
define build_gen_choice_in
	@echo '  IN   $(1)'
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

$(CT_TOP_DIR)/config.gen/arch.in: $(ARCH_CONFIG_FILES)
	$(call build_gen_choice_in,$(patsubst $(CT_TOP_DIR)/%,%,$@),Target Architecture,ARCH,config/arch,$(ARCHS))

$(CT_TOP_DIR)/config.gen/kernel.in: $(KERNEL_CONFIG_FILES)
	$(call build_gen_choice_in,$(patsubst $(CT_TOP_DIR)/%,%,$@),Target OS,KERNEL,config/kernel,$(KERNELS))

$(CT_TOP_DIR)/config.gen/libc.in: $(LIBC_CONFIG_FILES)
	$(call build_gen_choice_in,$(patsubst $(CT_TOP_DIR)/%,%,$@),C library,LIBC,config/libc,$(LIBCS))

# Function build_gen_menu_in:
# $1 : destination file
# $2 : name of entries family (eg. Tools, Debug...)
# $3 : prefix for the menu entries (eg. TOOL, DEBUG)
# $4 : base directory containing config files
# $5 : list of config entries (eg. for tools: "libelf sstrip"..., and for
#      debug: "dmalloc duma gdb"...)
# Example to build the tools generated config file:
# $(call build_gen_menu_in,config.gen/tools.in,Tools,TOOL,config/tools,$(TOOLS))
define build_gen_menu_in
	@echo '  IN   $(1)'
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

$(CT_TOP_DIR)/config.gen/tools.in: $(TOOL_CONFIG_FILES)
	$(call build_gen_menu_in,$(patsubst $(CT_TOP_DIR)/%,%,$@),Tools,TOOL,config/tools,$(TOOLS))

$(CT_TOP_DIR)/config.gen/debug.in: $(DEBUG_CONFIG_FILES)
	$(call build_gen_menu_in,$(patsubst $(CT_TOP_DIR)/%,%,$@),Debug,DEBUG,config/debug,$(DEBUGS))

config menuconfig oldconfig defoldconfig: $(KCONFIG_TOP)

$(KCONFIG_TOP):
	@ln -sf $(CT_LIB_DIR)/config config

menuconfig: $(CONFIG_FILES) $(obj)/mconf
	@$(obj)/mconf $(KCONFIG_TOP)

config: $(CONFIG_FILES) $(obj)/conf
	@$(obj)/conf $(KCONFIG_TOP)

oldconfig: $(CONFIG_FILES) $(obj)/conf
	@$(obj)/conf -s $(KCONFIG_TOP)

defoldconfig: $(CONFIG_FILES) $(obj)/conf
	@yes "" |$(obj)/conf -s $(KCONFIG_TOP)

# Help text used by make help
help-config::
	@echo  '  config             - Update current config using a line-oriented program'
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '                       build log piped into stdin'

# Cheesy build

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
	@echo '  LD   kconfig/mconf'
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{mconf.c,zconf.tab.c,lxdialog/*.c} \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ccflags)              \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ldflags $(HOST_CC))

$(obj)/conf: $(SHIPPED) $(CT_LIB_DIR)/kconfig/conf.c    \
             $(HEADERS) $(FILES)                        \
             $(CT_LIB_DIR)/kconfig/kconfig.mk
	@echo '  LD   kconfig/conf'
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{conf.c,zconf.tab.c}

clean::
	@rm -f $(CT_TOP_DIR)/kconfig/{,m}conf
	@rmdir --ignore-fail-on-non-empty $(CT_TOP_DIR)/kconfig 2>/dev/null || true
	@rm -f $(CT_TOP_DIR)/config 2>/dev/null || true
	@rm -rf $(CT_TOP_DIR)/config.gen
