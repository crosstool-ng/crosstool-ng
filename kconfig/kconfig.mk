# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

# The place where the kconfig stuff lies
obj = kconfig

#-----------------------------------------------------------
# The configurators rules

configurators = menuconfig oldconfig
PHONY += $(configurators)

$(configurators): config_files

menuconfig: $(obj)/mconf
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$< $(KCONFIG_TOP)

oldconfig: $(obj)/conf .config
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$< -s $(KCONFIG_TOP)

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

#-----------------------------------------------------------
# Hmmm! Cheesy build!
# Or: where I can unveil my make-fu... :-]

# Oh! Files not here are there, in fact! :-)
vpath %.c $(CT_LIB_DIR)
vpath %.h $(CT_LIB_DIR)

# What is the compiler?
HOST_CC ?= gcc -funsigned-char
HOST_LD ?= gcc

# Helpers
check_gettext = $(CT_LIB_DIR)/kconfig/check-gettext.sh
check_lxdialog = $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh

# Build flags
CFLAGS =
LDFLAGS =

# Compiler flags to use gettext
INTL_CFLAGS = $(shell $(SHELL) $(check_gettext) $(HOST_CC) $(EXTRA_CFLAGS))

# Compiler and linker flags to use ncurses
NCURSES_CFLAGS = $(shell $(SHELL) $(check_lxdialog) -ccflags)
NCURSES_LDFLAGS = $(shell $(SHELL) $(check_lxdialog) -ldflags $(HOST_CC) $(LX_FLAGS) $(EXTRA_CFLAGS))

# Common source files
COMMON_SRC = kconfig/zconf.tab.c
COMMON_OBJ = $(patsubst %.c,%.o,$(COMMON_SRC))
COMMON_DEP = $(patsubst %.o,%.dep,$(COMMON_OBJ))
$(COMMON_OBJ) $(COMMON_DEP): CFLAGS += $(INTL_CFLAGS)

# lxdialog source files
LX_SRC = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/kconfig/lxdialog/*.c))
LX_OBJ = $(patsubst %.c,%.o,$(LX_SRC))
LX_DEP = $(patsubst %.o,%.dep,$(LX_OBJ))
$(LX_OBJ) $(LX_DEP): CFLAGS += $(NCURSES_CFLAGS) $(INTL_CFLAGS)

# What's needed to build 'conf'
conf_SRC = kconfig/conf.c
conf_OBJ = $(patsubst %.c,%.o,$(conf_SRC))
conf_DEP = $(patsubst %.o,%.dep,$(conf_OBJ))
$(conf_OBJ) $(conf_DEP): CFLAGS += $(INTL_CFLAGS)

# What's needed to build 'mconf'
mconf_SRC = kconfig/mconf.c
mconf_OBJ = $(patsubst %.c,%.o,$(mconf_SRC))
mconf_DEP = $(patsubst %.c,%.dep,$(mconf_SRC))
$(mconf_OBJ) $(mconf_DEP): CFLAGS += $(NCURSES_CFLAGS) $(INTL_CFLAGS)
$(obj)/mconf: LDFLAGS += $(NCURSES_LDFLAGS)
ifeq ($(shell uname -o 2>/dev/null || echo unknown),Cygwin)
$(obj)/mconf: LDFLAGS += -Wl,--enable-auto-import
endif

# These are generated files:
ALL_OBJS = $(sort $(COMMON_OBJ) $(LX_OBJ) $(conf_OBJ) $(mconf_OBJ))
ALL_DEPS = $(sort $(COMMON_DEP) $(LX_DEP) $(conf_DEP) $(mconf_DEP))

# Cheesy auto-dependencies
# Only parse the following if a configurator was called, to avoid building
# dependencies when not needed (eg. list-steps, list-samples...)
# We must be carefull what we enclose, because we need some of the variable
# definitions for clean (and distclean) at least.
# Just protecting the "-include $(DEPS)" line should be sufficient.

ifneq ($(strip $(MAKECMDGOALS)),)
ifneq ($(strip $(filter $(configurators),$(MAKECMDGOALS))),)

DEPS = $(COMMON_DEP)
ifneq ($(strip $(filter oldconfig,$(MAKECMDGOALS))),)
DEPS += $(conf_DEP)
endif
ifneq ($(strip $(filter menuconfig,$(MAKECMDGOALS))),)
DEPS += $(mconf_DEP) $(LX_DEP)
endif

-include $(DEPS)

endif # MAKECMDGOALS contains a configurator rule
endif # MAKECMDGOALS != ""

# Each .o or .dep *can not* directly depend on kconfig/, because kconfig can
# be touched during the build (who's touching it, btw?) so each .o or .dep
# would be re-built when it sould not be.
# So manually check for presence of $(obj) (ie. kconfig), and only mkdir
# if needed. After all, that's not so bad...
# mkdir $(obj)/lxdialog, because we need it, and incidentally, that
# also creates $(obj).
define check_kconfig_dir
	$(SILENT)if [ ! -d $(obj)/lxdialog ]; then  \
	   $(ECHO) "  MKDIR $(obj)";           \
	   mkdir -p $(obj)/lxdialog;        \
	 fi
endef

# Build the dependency for C files
%.dep: %.c $(CT_LIB_DIR)/kconfig/kconfig.mk
	$(check_kconfig_dir)
	@$(ECHO) "  DEP   $@"
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) -MM $< |$(sed) -r -e 's|([^:]+.o)( *:+)|$(<:.c=.o) $@\2|;' >$@

# Build C files
%.o: %.c $(CT_LIB_DIR)/kconfig/kconfig.mk
	$(check_kconfig_dir)
	@$(ECHO) "  CC    $@"
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ -c $<

# Actual link
$(obj)/mconf: $(COMMON_OBJ) $(LX_OBJ) $(mconf_OBJ)
	@$(ECHO) '  LD    $@'
	$(SILENT)$(HOST_LD) -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)

$(obj)/conf: $(COMMON_OBJ) $(conf_OBJ)
	@$(ECHO) '  LD    $@'
	$(SILENT)$(HOST_LD) -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@$(ECHO) "  CLEAN kconfig"
	$(SILENT)rm -f kconfig/{,m}conf{,.exe} $(ALL_OBJS) $(ALL_DEPS)
	$(SILENT)rmdir --ignore-fail-on-non-empty kconfig{/lxdialog,} 2>/dev/null || true
