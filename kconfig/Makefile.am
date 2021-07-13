## vim: set noet :

## FIXME when kconfig is split into a subpackage, need to remove this option from sub-configure
transform		= s,x,x,

pkglibexec_PROGRAMS    = conf nconf mconf

EXTRA_DIST		= parser.y lexer.l \
				  expr.h list.h lkc.h lkc_proto.h nconf.h lxdialog/dialog.h \
				  menu.c

CLEANFILES		= lexer.lex.c parser.tab.c parser.tab.h
BUILT_SOURCES		= lexer.lex.c parser.tab.c

AM_LFLAGS		= -L
AM_YFLAGS		= -t -l
AM_CPPFLAGS		= -include config.h -DCONFIG_=\"CT_\"
AM_LIBTOOLFLAGS	= --tag CC

conf_SOURCES    = conf.c confdata.c expr.c symbol.c preprocess.c util.c
nodist_conf_SOURCES = parser.tab.c lexer.lex.c
conf_LDADD      = $(LIBINTL)

nconf_SOURCES	= nconf.c nconf.gui.c confdata.c expr.c symbol.c preprocess.c util.c
nodist_nconf_SOURCES = parser.tab.c lexer.lex.c
nconf_CFLAGS	= $(CURSES_CFLAGS)
nconf_LDADD     = $(MENU_LIBS) $(PANEL_LIBS) $(CURSES_LIBS) $(LIBINTL)

mconf_SOURCES	= mconf.c confdata.c expr.c symbol.c preprocess.c util.c \
				  lxdialog/checklist.c lxdialog/inputbox.c \
				  lxdialog/menubox.c lxdialog/textbox.c lxdialog/util.c \
				  lxdialog/yesno.c
nodist_mconf_SOURCES = parser.tab.c lexer.lex.c
mconf_LDADD     = $(CURSES_LIBS) $(LIBINTL)

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

parser.tab.c: parser.y
	$(AM_V_YACC)$(YACCCOMPILE) -o$@ --defines=parser.tab.h $<

lexer.lex.c: lexer.l
	$(AM_V_LEX)$(LEXCOMPILE) -o$@ $<
