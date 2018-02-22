## Process this file with automake to produce Makefile.in
## vim: set noet :

SUBDIRS		= kconfig

bin_SCRIPTS		= ct-ng
CLEANFILES		= $(bin_SCRIPTS)
EXTRA_DIST		= ct-ng.in bootstrap

do_subst		= ( @SED@ \
			-e 's,[@]bindir[@],$(bindir),g' \
			-e 's,[@]libdir[@],$(libdir),g' \
			-e 's,[@]docdir[@],$(docdir),g' \
			-e 's,[@]mandir[@],$(mandir),g' \
		| $(SHELL) config.status --file=- )

ct-ng: ct-ng.in
	$(AM_V_GEN)$(do_subst) < $< >$@-t && chmod a-w,a+x $@-t && mv $@-t $@
