# ===========================================================================
# crosstool-NG configuration targets
# These targets are used from top-level makefile

# Derive the project version from, well, the project version:
export PROJECTVERSION=$(CT_VERSION)

#-----------------------------------------------------------
# Some static /configuration/

# The place where the kconfig stuff lies
obj = kconfig

#-----------------------------------------------------------
# The configurators rules

PHONY += oldconfig menuconfig defoldconfig

menuconfig: $(obj)/mconf config_files
	@$(ECHO) "  MCONF $(KCONFIG_TOP)"
	$(SILENT)$< $(KCONFIG_TOP)

oldconfig: $(obj)/conf .config config_files
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$< -s $(KCONFIG_TOP)

defoldconfig: $(obj)/conf .config config_files
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)yes "" |$< -s $(KCONFIG_TOP)

#-----------------------------------------------------------
# Help text used by make help

help-config::
	@echo  '  menuconfig         - Update current config using a menu based program'
	@echo  '  oldconfig          - Update current config using a provided .config as base'
	@echo  '  defoldconfig       - As oldconfig, above, but using defaults for new options'

#-----------------------------------------------------------
# Hmmm! Cheesy build!
# Or: where I can unveil my make-fu... :-]

# Oh! Files not here are there, in fact! :-)
vpath %.c $(CT_LIB_DIR)
vpath %.h $(CT_LIB_DIR)

# What is the compiler?
HOST_CC ?= gcc -funsigned-char

# Compiler flags to use gettext
EXTRA_CFLAGS += $(shell $(SHELL) $(CT_LIB_DIR)/kconfig/check-gettext.sh $(HOST_CC) $(CFLAGS))

# Compiler and linker flags to use ncurses
EXTRA_CFLAGS += $(shell $(SHELL) $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ccflags)
EXTRA_LDFLAGS += $(shell $(SHELL) $(CT_LIB_DIR)/kconfig/lxdialog/check-lxdialog.sh -ldflags $(HOST_CC))

# Common source files, and lxdialog source files
SRC = kconfig/zconf.tab.c
LXSRC = $(patsubst $(CT_LIB_DIR)/%,%,$(wildcard $(CT_LIB_DIR)/kconfig/lxdialog/*.c))

# What's needed to build 'conf'
conf_SRC  = $(SRC) kconfig/conf.c
conf_OBJ  = $(patsubst %.c,%.o,$(conf_SRC))

# What's needed to build 'mconf'
mconf_SRC = $(SRC) $(LXSRC) kconfig/mconf.c
mconf_OBJ = $(patsubst %.c,%.o,$(mconf_SRC))

# Cheesy auto-dependencies
DEPS = $(patsubst %.c,%.dep,$(sort $(conf_SRC) $(mconf_SRC)))
-include $(DEPS)

# This is not very nice, as they will get rebuild even if (dist)cleaning... :-(
# Should look into the Linux kernel Kbuild to see how they do that...
# To really make me look into this, keep the annoying "DEP xxx" messages.
# Also see the comment for the "%.o: %c" rule below
%.dep: %.c $(CT_LIB_DIR)/kconfig/kconfig.mk $(CT_NG)
	$(SILENT)if [ ! -d $(obj)/lxdialog ]; then  \
	   $(ECHO) "  MKDIR $(obj)";           \
	   mkdir -p $(obj)/lxdialog;        \
	 fi
	@$(ECHO) "  DEP   $@"
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) -MM $< |sed -r -e 's|([^:]+.o)( *:+)|$(<:.c=.o) $@\2|;' >$@

# Each .o must depend on the corresponding .c (obvious, isn't it?),
# but *can not* depend on kconfig/, because kconfig can be touched
# during the build (who's touching it, btw?) so each .o would be
# re-built when they sould not be.
# So manually check for presence of $(obj) (ie. kconfig), and only mkdir
# if needed. After all, that's not so bad...
# mkdir $(obj)/lxdialog, because we need it, and incidentally, that
# also creates $(obj).
# Also rebuild the object files is the makefile is changed
%.o: %.c $(CT_LIB_DIR)/kconfig/kconfig.mk
	$(SILENT)if [ ! -d $(obj)/lxdialog ]; then  \
	   $(ECHO) "  MKDIR $(obj)";           \
	   mkdir -p $(obj)/lxdialog;        \
	 fi
	@$(ECHO) "  CC    $@"
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ -c $<

$(obj)/mconf: $(mconf_OBJ)
	@$(ECHO) '  LD    $@'
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ $^

$(obj)/conf: $(conf_OBJ)
	@$(ECHO) '  LD    $@'
	$(SILENT)$(HOST_CC) $(CFLAGS) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ $^

#-----------------------------------------------------------
# Cleaning up the mess...

clean::
	@$(ECHO) "  CLEAN kconfig"
	$(SILENT)rm -f kconfig/{,m}conf $(conf_OBJ) $(mconf_OBJ) $(DEPS)
	$(SILENT)rmdir --ignore-fail-on-non-empty kconfig{/lxdialog,} 2>/dev/null || true
