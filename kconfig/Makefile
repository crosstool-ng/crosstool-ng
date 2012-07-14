#-----------------------------------------------------------
# Hmmm! Cheesy build!
# Or: where I can unveil my make-fu... :-]

all: conf mconf nconf
	@true   # Just be silent, you fscking son of a fscking beach...

# Build flags
CFLAGS = -DCONFIG_=\"CT_\" -DPACKAGE="\"crosstool-NG $(VERSION)\""
LDFLAGS =

# Compiler flags to use gettext
ifeq ($(gettext),)
INTL_CFLAGS = -DKBUILD_NO_NLS
endif

# Compiler and linker flags to use ncurses
NCURSES_CFLAGS = -DCURSES_LOC="\"$(curses_hdr)\""
NCURSES_LDFLAGS = $(LIBS)

# Common source files
COMMON_SRC = zconf.tab.c
COMMON_OBJ = $(patsubst %.c,%.o,$(COMMON_SRC))
COMMON_DEP = $(patsubst %.o,%.dep,$(COMMON_OBJ))
$(COMMON_OBJ) $(COMMON_DEP): CFLAGS += $(INTL_CFLAGS) -I.

# lxdialog source files
LX_SRC = $(wildcard lxdialog/*.c)
LX_OBJ = $(patsubst %.c,%.o,$(LX_SRC))
LX_DEP = $(patsubst %.o,%.dep,$(LX_OBJ))
$(LX_OBJ) $(LX_DEP): CFLAGS += $(NCURSES_CFLAGS) $(INTL_CFLAGS)

# What's needed to build 'conf'
conf_SRC = conf.c
conf_OBJ = $(patsubst %.c,%.o,$(conf_SRC))
conf_DEP = $(patsubst %.o,%.dep,$(conf_OBJ))
$(conf_OBJ) $(conf_DEP): CFLAGS += $(INTL_CFLAGS)

# What's needed to build 'mconf'
mconf_SRC = mconf.c
mconf_OBJ = $(patsubst %.c,%.o,$(mconf_SRC))
mconf_DEP = $(patsubst %.c,%.dep,$(mconf_SRC))
$(mconf_OBJ) $(mconf_DEP): CFLAGS += $(NCURSES_CFLAGS) $(INTL_CFLAGS)
mconf: LDFLAGS += $(NCURSES_LDFLAGS)

# What's needed to build 'nconf'
nconf_SRC = nconf.c nconf.gui.c
nconf_OBJ = $(patsubst %.c,%.o,$(nconf_SRC))
nconf_DEP = $(patsubst %.c,%.dep,$(nconf_SRC))
$(nconf_OBJ) $(nconf_DEP): CFLAGS += $(INTL_CFLAGS)
nconf: LDFLAGS += -lmenu -lpanel -lncurses

# Under Cygwin, we need to auto-import some libs (which ones, exactly?)
# for mconf and nconf to lin properly.
ifeq ($(shell uname -o 2>/dev/null || echo unknown),Cygwin)
mconf: LDFLAGS += -Wl,--enable-auto-import
nconf: LDFLAGS += -Wl,--enable-auto-import
endif

# These are generated files:
ALL_OBJS = $(sort $(COMMON_OBJ) $(LX_OBJ) $(conf_OBJ) $(mconf_OBJ) $(nconf_OBJ))
ALL_DEPS = $(sort $(COMMON_DEP) $(LX_DEP) $(conf_DEP) $(mconf_DEP) $(nconf_DEP))

# Cheesy auto-dependencies
DEPS = $(COMMON_DEP)
DEPS += $(conf_DEP)
DEPS += $(mconf_DEP) $(LX_DEP)
DEPS += $(nconf_DEP)
-include $(DEPS)

# Build the dependency for C files
%.dep: %.c
	@echo "  DEP    '$@'"
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -MM $< |$(sed) -r -e 's|([^:]+.o)( *:+)|$(<:.c=.o) $@\2|;' >$@

# Generate the grammar parser
zconf.tab.o: zconf.tab.c zconf.hash.c lex.zconf.c
zconf.tab.dep: zconf.tab.c zconf.hash.c lex.zconf.c

.PRECIOUS: zconf.tab.c
zconf.tab.c: zconf.y
	@echo "  BISON  '$@'"
	@bison -l -b zconf -p zconf $<

zconf.hash.c: zconf.gperf
	@echo "  GPERF  '$@'"
	@gperf < $< > $@

lex.zconf.c: zconf.l
	@echo "  LEX    '$@'"
	@flex -L -Pzconf -o$@ $<

# Build C files
%.o: %.c
	@echo "  CC     '$@'"
	@$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ -c $<

# Actual link
mconf: $(COMMON_OBJ) $(LX_OBJ) $(mconf_OBJ)
	@echo "  LD     '$@'"
	@$(CC) -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)

nconf: $(COMMON_OBJ) $(nconf_OBJ)
	@echo "  LD     '$@'"
	@$(CC) -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)

conf: $(COMMON_OBJ) $(conf_OBJ)
	@echo "  LD     '$@'"
	@$(CC) -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)

#-----------------------------------------------------------
# Cleaning up the mess...

clean:
	@echo "  RM     'kconfig'"
	@rm -f conf mconf nconf $(ALL_OBJS) $(ALL_DEPS)
	@rm -f rm -f zconf.tab.c zconf.hash.c lex.zconf.c lex.backup
