# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

KCONFIG_TOP = config/config.in
obj = $(CT_TOP_DIR)/kconfig
PHONY += clean help oldconfig menuconfig config defoldconfig extractconfig

# Darwin (MacOS-X) does not have proper libintl support
ifeq ($(shell uname -s),Darwin)
KBUILD_NO_NLS:=1
endif

ifneq ($(KBUILD_NO_NLS),)
CFLAGS += -DKBUILD_NO_NLS
endif

# Build a list of all config files
ARCHS              = $(patsubst $(CT_LIB_DIR)/arch/%,%,$(wildcard $(CT_LIB_DIR)/arch/*))
ARCH_CONFIG_FILE   = $(wildcard $(CT_LIB_DIR)/arch/*/*.in)
DEBUG_CONFIG_FILES = $(wildcard $(CT_LIB_DIR)/config/debug/*.in)
TOOLS_CONFIG_FILES = $(wildcard $(CT_LIB_DIR)/config/tools/*.in)

STATIC_CONFIG_FILES = $(shell find $(CT_LIB_DIR)/config -type f -name '*.in')
GEN_CONFIG_FILES=$(CT_TOP_DIR)/config.gen/arch.in	\
				 $(CT_TOP_DIR)/config.gen/debug.in	\
				 $(CT_TOP_DIR)/config.gen/tools.in

CONFIG_FILES=$(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

$(GEN_CONFIG_FILES):: $(CT_TOP_DIR)/config.gen

$(CT_TOP_DIR)/config.gen:
	@mkdir -p $(CT_TOP_DIR)/config.gen

$(CT_TOP_DIR)/config.gen/arch.in:: $(ARCH_CONFIG_FILES)
	@(echo "# Architectures menu";                                              \
	  echo "# Generated file, do not edit!!!";                                  \
	  echo "";                                                                  \
	  for arch in $(ARCHS); do                                                  \
	    echo "config ARCH_$${arch}";                                            \
	    echo "    bool";                                                        \
	    echo -n "    prompt \"$${arch}";                                        \
	    if [ -f $(CT_LIB_DIR)/arch/$${arch}/experimental ]; then                \
	      echo " (EXPERIMENTAL)\"";                                             \
	      echo "    depends on EXPERIMENTAL";                                   \
	    else                                                                    \
	      echo "\"";                                                            \
	    fi;                                                                     \
	    echo "if ARCH_$${arch}";                                                \
	    echo "config ARCH";                                                     \
	    echo "    default \"$${arch}\" if ARCH_$${arch}";                       \
	    echo "source config/arch/$${arch}/config.in";                           \
	    echo "endif";                                                           \
	    echo "";                                                                \
	  done;                                                                     \
	) >$@

$(CT_TOP_DIR)/config.gen/debug.in:: $(DEBUG_CONFIG_FILES)
	@echo "# Debug facilities menu" >$@
	@echo "# Generated file, do not edit!!!" >>$@
	@echo "menu \"Debug facilities\"" >>$@
	@for f in $(patsubst $(CT_TOP_DIR)/%,%,$(wildcard $(CT_TOP_DIR)/config/debug/*.in)); do \
	     echo "source $${f}";                                                               \
	 done >>$@
	@echo "endmenu" >>$@

$(CT_TOP_DIR)/config.gen/tools.in:: $(TOOLS_CONFIG_FILES)
	@echo "# Tools facilities menu" >$@
	@echo "# Generated file, do not edit!!!" >>$@
	@echo "menu \"Tools facilities\"" >>$@
	@for f in $(patsubst $(CT_TOP_DIR)/%,%,$(wildcard $(CT_TOP_DIR)/config/tools/*.in)); do \
	     echo "source $${f}";                                                               \
	 done >>$@
	@echo "endmenu" >>$@

config menuconfig oldconfig defoldconfig extractconfig:: $(KCONFIG_TOP)

$(KCONFIG_TOP):
	@ln -sf $(CT_LIB_DIR)/config config

menuconfig:: $(obj)/mconf $(CONFIG_FILES)
	@$< $(KCONFIG_TOP)

config:: $(obj)/conf $(CONFIG_FILES)
	@$< $(KCONFIG_TOP)

oldconfig:: $(obj)/conf $(CONFIG_FILES)
	@$< -s $(KCONFIG_TOP)

defoldconfig:: $(obj)/conf $(CONFIG_FILES)
	@yes "" |$< -s $(KCONFIG_TOP) >/dev/null

extractconfig:: $(obj)/conf $(CONFIG_FILES)
	@$(CT_LIB_DIR)/tools/extract-config.sh >.config
	@$< -s $(KCONFIG_TOP)

# Help text used by make help
help-config::
	@echo  '  config             - Update current config using a line-oriented program'
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '  extractconfig      - Create a new config using options extracted from a'
	@echo  '                       build log piped into stdin'

# Cheesy build

SHIPPED := $(CT_LIB_DIR)/kconfig/zconf.tab.c $(CT_LIB_DIR)/kconfig/lex.zconf.c $(CT_LIB_DIR)/kconfig/zconf.hash.c

%.c: %.c_shipped
	@ln -s $(notdir $<) $@

$(obj)/conf $(obj)/mconf:: $(obj)

$(obj):
	@mkdir -p $(obj)

$(obj)/mconf:: $(SHIPPED) $(CT_LIB_DIR)/kconfig/mconf.c
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{mconf.c,zconf.tab.c,lxdialog/*.c} \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ccflags)              \
	     $(shell $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ldflags $(HOST_CC))

$(obj)/conf:: $(SHIPPED) $(CT_LIB_DIR)/kconfig/conf.c
	@$(HOST_CC) $(CFLAGS) -o $@ $(CT_LIB_DIR)/kconfig/{conf.c,zconf.tab.c}

clean::
	@rm -f $(CT_TOP_DIR)/kconfig/{,m}conf
	@rm -f $(SHIPPED)
	@rmdir --ignore-fail-on-non-empty $(CT_TOP_DIR)/kconfig 2>/dev/null || true
	@rm -f $(CT_TOP_DIR)/config 2>/dev/null || true
	@rm -rf $(CT_TOP_DIR)/config.gen
