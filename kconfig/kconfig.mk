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
ARCH_CONFIG_FILES  = $(wildcard $(CT_LIB_DIR)/config/arch/*/config.in)
KERN_CONFIG_FILES  = $(wildcard $(CT_LIB_DIR)/config/kernel/*.in)
DEBUG_CONFIG_FILES = $(wildcard $(CT_LIB_DIR)/config/debug/*.in)
TOOLS_CONFIG_FILES = $(wildcard $(CT_LIB_DIR)/config/tools/*.in)

STATIC_CONFIG_FILES = $(shell find $(CT_LIB_DIR)/config -type f -name '*.in')
GEN_CONFIG_FILES=$(CT_TOP_DIR)/config.gen/arch.in	\
				 $(CT_TOP_DIR)/config.gen/kernel.in	\
				 $(CT_TOP_DIR)/config.gen/debug.in	\
				 $(CT_TOP_DIR)/config.gen/tools.in

CONFIG_FILES=$(STATIC_CONFIG_FILES) $(GEN_CONFIG_FILES)

# Build list of items
ARCHS   = $(patsubst $(CT_LIB_DIR)/config/arch/%/config.in,%,$(ARCH_CONFIG_FILES))
KERNELS = $(patsubst $(CT_LIB_DIR)/config/kernel/%.in,%,$(KERN_CONFIG_FILES))

$(GEN_CONFIG_FILES): $(CT_TOP_DIR)/config.gen           \
                     $(CT_LIB_DIR)/kconfig/kconfig.mk

$(CT_TOP_DIR)/config.gen: $(KCONFIG_TOP)
	@mkdir -p $(CT_TOP_DIR)/config.gen

$(CT_TOP_DIR)/config.gen/arch.in: $(ARCH_CONFIG_FILES)
	@echo '  IN   config.gen/arch.in'
	@(echo "# Architectures menu";                                                              \
	  echo "# Generated file, do not edit!!!";                                                  \
	  echo "";                                                                                  \
	  for arch in $(ARCHS); do                                                                  \
	    _arch=$$(echo "$${arch}" |sed -r -s -e 's/[-.+]/_/g;');                                 \
	    echo "config ARCH_$${_arch}";                                                           \
	    echo "    bool";                                                                        \
	    printf "    prompt \"$${arch}";                                                         \
	    if grep -E '^# +EXPERIMENTAL$$' config/arch/$${arch}/config.in >/dev/null 2>&1; then    \
	      echo " (EXPERIMENTAL)\"";                                                             \
	      echo "    depends on EXPERIMENTAL";                                                   \
	    else                                                                                    \
	      echo "\"";                                                                            \
	    fi;                                                                                     \
	    echo "if ARCH_$${_arch}";                                                               \
	    echo "config ARCH";                                                                     \
	    echo "    default \"$${arch}\" if ARCH_$${_arch}";                                      \
	    echo "source config/arch/$${arch}/config.in";                                           \
	    echo "endif";                                                                           \
	    echo "";                                                                                \
	  done;                                                                                     \
	 ) >$@

$(CT_TOP_DIR)/config.gen/kernel.in: $(KERN_CONFIG_FILES)
	@echo '  IN   config.gen/kernel.in'
	@(echo "# Kernel menu";                                                             \
	  echo "# Generated file, do not edit!!!";                                          \
	  echo "";                                                                          \
	  for kern in $(KERNELS); do                                                        \
	    _kern=$$(echo "$${kern}" |sed -r -s -e 's/[-.+]/_/g;');                         \
	    echo "config KERNEL_$${_kern}";                                                 \
	    echo "    bool";                                                                \
	    printf "    prompt \"$${kern}";                                                 \
	    if grep -E '^# +EXPERIMENTAL$$' config/kernel/$${kern}.in >/dev/null 2>&1; then \
	      echo " (EXPERIMENTAL)\"";                                                     \
	      echo "  depends on EXPERIMENTAL";                                             \
	    else                                                                            \
	      echo "\"";                                                                    \
		fi;                                                                             \
	    echo "if KERNEL_$${_kern}";                                                     \
	    echo "config KERNEL";                                                           \
	    echo "    default \"$${kern}\" if KERNEL_$${_kern}";                            \
	    echo "source config/kernel/$${kern}.in";                                        \
	    echo "endif";                                                                   \
	    echo "";                                                                        \
	  done;                                                                             \
	 ) >$@

$(CT_TOP_DIR)/config.gen/debug.in: $(DEBUG_CONFIG_FILES)
	@echo '  IN   config.gen/debug.in'
	@(echo "# Debug facilities menu";                                   \
	  echo "# Generated file, do not edit!!!";                          \
	  echo "menu \"Debug facilities\"";                                 \
	  for f in $(patsubst $(CT_LIB_DIR)/%,%,$(DEBUG_CONFIG_FILES)); do  \
	     echo "source $${f}";                                           \
	  done;                                                             \
	  echo "endmenu";                                                   \
	 ) >$@

$(CT_TOP_DIR)/config.gen/tools.in: $(TOOLS_CONFIG_FILES)
	@echo '  IN   config.gen/tools.in'
	@(echo "# Tools facilities menu";                                   \
	  echo "# Generated file, do not edit!!!";                          \
	  echo "menu \"Tools facilities\"";                                 \
	  for f in $(patsubst $(CT_LIB_DIR)/%,%,$(TOOLS_CONFIG_FILES)); do  \
	     echo "source $${f}";                                           \
	  done;                                                             \
	  echo "endmenu";                                                   \
	 ) >$@

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
