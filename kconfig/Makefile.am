## Process this file with automake to produce Makefile.in
## vim: set noet :

## TBD install into lib/crosstool-ng/kconfig?
## TBD turn off program renaming for these? Or account for it in ct-ng script?
pkglibexec_PROGRAMS    = conf nconf

AM_LFLAGS		= -L -Pzconf
AM_YFLAGS		= -l -b zconf -p zconf

BUILT_SOURCES	= zconf.c zconf.lex.c

AM_CPPFLAGS		= -include config.h -DCONFIG_=\"CT_\"

conf_SOURCES    = conf.c zconf.c

nconf_SOURCES	= nconf.c nconf.gui.c zconf.c
nconf_CFLAGS	= $(CURSES_CFLAGS)
nconf_LDADD		= $(MENU_LIBS) $(PANEL_LIBS) $(CURSES_LIBS)

# automake's support for yacc/lex/gperf is too idiosyncratic. It doesn't
# support a common pattern of including lex-generated file into yacc, nor does
# it support using a different base name for the generated C files.
YACCCOMPILE	= $(YACC) $(AM_YFLAGS) $(YFLAGS)
AM_V_YACC		= $(am__v_YACC_@AM_V@)
am__v_YACC_		= $(am__v_YACC_@AM_DEFAULT_V@)
am__v_YACC_0	= @echo "  YACC    " $@;

LEXCOMPILE	= $(LEX) $(AM_LFLAGS) $(LFLAGS)
AM_V_LEX		= $(am__v_LEX_@AM_V@)
am__v_LEX_		= $(am__v_LEX_@AM_DEFAULT_V@)
am__v_LEX_0		= @echo "  LEX     " $@;

zconf.c: zconf.y
	$(AM_V_YACC)$(YACCCOMPILE) -o$@ $<

zconf.lex.c: zconf.l
	$(AM_V_LEX)$(LEXCOMPILE) -o$@ $<
