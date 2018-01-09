# Makefile.in for building crosstool-NG
# This file serves as source for the ./configure operation

# This series of test is here because GNU make 3.81 will *not* use MAKEFLAGS
# to set additional flags in the current Makfile ( see:
# http://savannah.gnu.org/bugs/?20501 ), although the make manual says it
# should ( see: http://www.gnu.org/software/make/manual/make.html#Options_002fRecursion )
# so we have to work it around by calling ourselves back if needed

# So why do we need not to use the built rules and variables? Because we
# need to generate scripts/crosstool-NG.sh from scripts/crosstool-NG.sh.in
# and there is a built-in implicit rule '%.sh:' that has neither a pre-requisite
# nor a command associated, and that built-in implicit rule takes precedence
# over our non-built-in implicit rule '%: %.in', below.

# CT_MAKEFLAGS will be used later, below...

# Do not print directories as we descend into them
ifeq ($(filter --no-print-directory,$(MAKEFLAGS)),)
CT_MAKEFLAGS += --no-print-directory
endif

# Use neither builtin rules, nor builtin variables
# Note: dual test, because if -R and -r are given on the command line
# (who knows?), MAKEFLAGS contains 'Rr' instead of '-Rr', while adding
# '-Rr' to MAKEFLAGS adds it literaly ( and does not add 'Rr' )
# Further: quad test because the flags 'rR' and '-rR' can be reordered.
ifeq ($(filter Rr,$(MAKEFLAGS)),)
ifeq ($(filter -Rr,$(MAKEFLAGS)),)
ifeq ($(filter rR,$(MAKEFLAGS)),)
ifeq ($(filter -rR,$(MAKEFLAGS)),)
CT_MAKEFLAGS += -Rr
endif # No -rR
endif # No rR
endif # No -Rr
endif # No Rr

# Helper: print abbreviation of the command by default, or full command
# if doing 'make V=1'.
__silent = $(if $(V),,@printf '  %-7s %s\n' '$1' '$(if $2,$2,$(strip $<))' && )
__silent_rm = $(call __silent,RM,$1)rm -f $1
__silent_rmdir = $(call __silent,RMDIR,$1)rm -rf $1

# Remove any suffix rules
.SUFFIXES:

all: Makefile build

###############################################################################
# Configuration variables

# Stuff found by ./configure
export DATE            := 20180109
export LOCAL           := no
export PROG_SED        := s,x,x,
export PACKAGE_TARNAME := crosstool-ng
export VERSION         := crosstool-ng-1.23.0-288-gadaa3a5-dirty
export prefix          := /usr/local
export exec_prefix     := ${prefix}
export bindir          := ${exec_prefix}/bin
export libdir          := ${exec_prefix}/lib/${VERSION}
export docdir          := ${datarootdir}/doc/${PACKAGE_TARNAME}/${VERSION}
export mandir          := ${datarootdir}/man
export datarootdir     := ${prefix}/share
export install         := /usr/bin/install -c
export bash            := /bin/bash
export awk             := /usr/bin/gawk
export grep            := /bin/grep
export make            := /usr/bin/make
export sed             := /bin/sed
export wget            := wget
export curl            := 
export libtool         := 
export libtoolize      := /usr/bin/libtoolize
export objcopy         := /usr/bin/objcopy
export objdump         := /usr/bin/objdump
export readelf         := /usr/bin/readelf
export patch           := /usr/bin/patch
export gperf           := /usr/bin/gperf
export gperf_len_type  := size_t
export CC              := gcc
export CPP             := gcc -E
export CPPFLAGS        := 
export CFLAGS          := -g -O2
export LDFLAGS         := 
export LIBS            := -lncurses 
export INTL_LIBS       := 
export curses_hdr      := ncurses.h
export gettext         := y
export CPU_COUNT       := getconf _NPROCESSORS_ONLN

###############################################################################
# Non-configure variables
MAN_SECTION := 1
MAN_SUBDIR := /man$(MAN_SECTION)

PROG_NAME := $(shell echo 'ct-ng' |$(sed) -r -e '$(PROG_SED)' )

###############################################################################
# Sanity checks

# Check if Makefile is up to date:
Makefile: Makefile.in
	@echo "$< changed: you must re-run './configure'"
	@false

# If installing with DESTDIR, check it's an absolute path
ifneq ($(strip $(DESTDIR)),)
  ifneq ($(DESTDIR),$(abspath /$(DESTDIR)))
    $(error DESTDIR is not an absolute PATH: '$(DESTDIR)')
  endif
endif

###############################################################################
# Global make rules

# If any extra MAKEFLAGS were added, re-run ourselves
# See top of file for an explanation of why this is needed...
ifneq ($(strip $(CT_MAKEFLAGS)),)

# Somehow, the new auto-completion for make in the recent distributions
# trigger a behavior where our Makefile calls itself recursively, in a
# never-ending loop (except on lack of ressources, swap, PIDs...)
# Avoid this situation by cutting the recursion short at the first
# level.
# This has the side effect of only showing the real targets, and hiding our
# internal ones. :-)
ifneq ($(MAKELEVEL),0)
$(error Recursion detected, bailing out...)
endif

MAKEFLAGS += $(CT_MAKEFLAGS)
build install clean distclean mrproper uninstall:
	@$(MAKE) $@

else
# There were no additional MAKEFLAGS to add, do the job

TARGETS := bin lib lib-kconfig doc man

build: $(patsubst %,build-%,$(TARGETS))

install: build real-install

clean: $(patsubst %,clean-%,$(TARGETS))

distclean: clean
	$(call __silent_rm,Makefile kconfig/Makefile config/configure.in)

mrproper: distclean
	$(call __silent_rmdir,autom4te.cache config/gen config/versions)
	$(call __silent_rm,config.log config.status configure)

uninstall: real-uninstall

###############################################################################
# Specific make rules

#--------------------------------------
# Build rules

build-bin: $(PROG_NAME)             \
           scripts/scripts.mk       \
           scripts/crosstool-NG.sh  \
           scripts/saveSample.sh

build-lib: paths.mk             \
           paths.sh

build-lib-kconfig:
	$(call __silent,ENTER,kconfig)$(MAKE) -C kconfig
	$(call __silent,LEAVE,kconfig):

build-doc:

build-man: docs/$(PROG_NAME).1.gz

docs/$(PROG_NAME).1.gz: docs/$(PROG_NAME).1
	$(call __silent,GZIP)gzip -c9n $< >$@

define sed_it
	$(call __silent,SED,$@)$(sed) -r                    \
	           -e 's,@@CT_BINDIR@@,$(bindir),g;'        \
	           -e 's,@@CT_LIBDIR@@,$(libdir),g;'        \
	           -e 's,@@CT_DOCDIR@@,$(docdir),g;'        \
	           -e 's,@@CT_MANDIR@@,$(mandir),g;'        \
	           -e 's,@@CT_PROG_NAME@@,$(PROG_NAME),g;'  \
	           -e 's,@@CT_VERSION@@,$(VERSION),g;'	    \
	           -e 's,@@CT_DATE@@,$(DATE),g;'            \
	           -e 's,@@CT_make@@,$(make),g;'            \
	           -e 's,@@CT_bash@@,$(bash),g;'            \
	           -e 's,@@CT_awk@@,$(awk),g;'              \
	           -e 's,@@CT_wget@@,$(wget),g;'            \
	           -e 's,@@CT_curl@@,$(curl),g;'            \
	           -e 's,@@CT_cpucount@@,$(CPU_COUNT),g;'   \
	           $< >$@
endef

docs/$(PROG_NAME).1: docs/ct-ng.1.in Makefile
	$(call sed_it)

$(PROG_NAME): ct-ng.in Makefile
	$(call sed_it)
	$(call __silent,CHMOD,$@)chmod 755 $@

%: %.in Makefile
	$(call sed_it)

__paths_vars	= install bash awk grep make sed libtool \
		  libtoolize objcopy objdump readelf patch gperf

# We create a script fragment that is parseable from inside a Makefile,
# and one from inside a shell script.
paths.mk: FORCE
	$(call __silent,GEN,$@){ $(foreach w,$(__paths_vars),$(if $($w),echo 'export $w=$(subst ','\'',$($w))';)) :; } >$@

paths.sh: FORCE
	$(call __silent,GEN,$@){ $(foreach w,$(__paths_vars),$(if $($w),echo 'export $w="$(subst ','\'',$($w))"';)) :; } >$@

FORCE:

#--------------------------------------
# Clean rules

clean-bin:
	$(call __silent_rm,$(PROG_NAME))
	$(call __silent_rm,scripts/scripts.mk)
	$(call __silent_rm,scripts/crosstool-NG.sh)
	$(call __silent_rm,scripts/saveSample.sh)

clean-lib:
	$(call __silent_rm,paths.mk paths.sh)

clean-lib-kconfig:
	$(call __silent,ENTER,kconfig)$(MAKE) -C kconfig clean
	$(call __silent,LEAVE,kconfig):

clean-doc:

clean-man:
	$(call __silent_rm,docs/$(PROG_NAME).1)
	$(call __silent_rm,docs/$(PROG_NAME).1.gz)

#--------------------------------------
# Check for --local setup

ifeq ($(strip $(LOCAL)),yes)

real-install:
	@true

real-uninstall:
	@true

else

#--------------------------------------
# Install rules

real-install: $(patsubst %,install-%,$(TARGETS)) install-post

install-bin: $(DESTDIR)$(bindir)
	$(call __silent,INST,$(PROG_NAME))$(install) -m 755 $(PROG_NAME) "$(DESTDIR)$(bindir)/$(PROG_NAME)"

# If one is hacking crosstool-NG, the patch set might change between any two
# installations of the same VERSION, thus the patches must be removed prior
# to being installed. It is the responsibility of the user to call uninstall
# first, if (s)he deems it necessary
install-lib: $(DESTDIR)$(libdir)    \
             install-lib-main       \
             install-lib-samples

LIB_SUB_DIR := config contrib packages scripts
$(patsubst %,install-lib-%-copy,$(LIB_SUB_DIR)): install-lib-%-copy: $(DESTDIR)$(libdir)
	$(call __silent,INSTDIR,$*)tar cf - --exclude='*.sh.in' --exclude='*.in.in' --exclude=.gitignore $* \
	 |(cd "$(DESTDIR)$(libdir)"; tar xf -)

# Dependency-only by default.
$(patsubst %,install-lib-%,$(LIB_SUB_DIR)): install-lib-%: install-lib-%-copy

install-lib-main: $(DESTDIR)$(libdir) $(patsubst %,install-lib-%,$(LIB_SUB_DIR))
	$(call __silent,INST,steps.mk)$(install) -m 644 steps.mk "$(DESTDIR)$(libdir)"
	$(call __silent,INST,paths.mk)$(install) -m 644 paths.mk "$(DESTDIR)$(libdir)"
	$(call __silent,INST,paths.sh)$(install) -m 644 paths.sh "$(DESTDIR)$(libdir)"

# Samples need a little love:
#  - change every occurrence of CT_TOP_DIR to CT_LIB_DIR
install-lib-samples: $(DESTDIR)$(libdir) install-lib-main
	$(call __silent,INSTDIR,samples)for samp_dir in samples/*/; do          \
	     mkdir -p "$(DESTDIR)$(libdir)/$${samp_dir}";                       \
	     $(sed) -r -e 's:\$$\{CT_TOP_DIR\}:\$$\{CT_LIB_DIR\}:;'             \
	               -e 's:^(CT_WORK_DIR)=.*:\1="\$${CT_TOP_DIR}/.build":;'   \
	            $${samp_dir}/crosstool.config                               \
	            >"$(DESTDIR)$(libdir)/$${samp_dir}/crosstool.config";       \
	     $(install) -m 644 "$${samp_dir}/reported.by"                       \
	                       "$(DESTDIR)$(libdir)/$${samp_dir}";              \
	     for libc_cfg in "$${samp_dir}/"*libc*.config; do                   \
	         [ -f "$${libc_cfg}" ] || continue;                             \
	         $(install) -m 644 "$${libc_cfg}"                               \
	                           "$(DESTDIR)$(libdir)/$${samp_dir}";          \
	     done;                                                              \
	     [ -e "$${samp_dir}/broken" ] &&                                    \
                 $(install) -m 644 "$${samp_dir}/broken"                        \
                    "$(DESTDIR)$(libdir)/$${samp_dir}/" || :;                   \
	 done
	@$(install) -m 644 samples/samples.mk "$(DESTDIR)$(libdir)/samples/samples.mk"

install-lib-kconfig: $(DESTDIR)$(libdir) install-lib-main
	$(call __silent,MKDIR,$@)$(install) -m 755 -d "$(DESTDIR)$(libdir)/kconfig"
	$(call __silent,ENTER,kconfig)$(MAKE) -C kconfig install \
		DESTDIR=$(DESTDIR)$(libdir)/kconfig
	$(call __silent,LEAVE,kconfig):

install-doc: install-doc-$(if $(wildcard docs/MANUAL_ONLINE),message,real)

install-doc-message:
	@echo "********************************************************************"
	@echo "  You are building from a development version that does not include"
	@echo "  the documentation. Refer to the manual online at:"
	@echo "      http://crosstool-ng.github.io/docs"
	@echo "********************************************************************"

install-doc-real: $(DESTDIR)$(docdir)
	$(call __silent,INST,docs)for doc_file in docs/manual/*.md; do     \
	     $(install) -m 644 "$${doc_file}" "$(DESTDIR)$(docdir)"; \
	done

install-man: $(DESTDIR)$(mandir)$(MAN_SUBDIR)
	$(call __silent,INST,$(PROG_NAME).1.gz)$(install) -m 644 docs/$(PROG_NAME).1.gz "$(DESTDIR)$(mandir)$(MAN_SUBDIR)"

$(sort $(DESTDIR)$(bindir) $(DESTDIR)$(libdir) $(DESTDIR)$(docdir) $(DESTDIR)$(mandir)$(MAN_SUBDIR)):
	$(call __silent,MKDIR,$@)$(install) -m 755 -d "$@"

install-post:
	@echo
	@echo "For auto-completion, do not forget to install '$(PROG_NAME).comp' into"
	@echo "your bash completion directory (usually /etc/bash_completion.d)"

#--------------------------------------
# Uninstall rules

real-uninstall: $(patsubst %,uninstall-%,$(filter-out lib-kconfig,$(TARGETS)))

uninstall-bin:
	$(call __silent_rm,$(DESTDIR)$(bindir)/$(PROG_NAME))

uninstall-lib:
	$(call __silent_rmdir,$(DESTDIR)$(libdir))

uninstall-doc:
	$(call __silent_rmdir,$(DESTDIR)$(docdir))

uninstall-man:
	$(call __silent_rm,$(DESTDIR)$(mandir)$(MAN_SUBDIR)/$(PROG_NAME).1.gz)

endif # Not --local

endif # No extra MAKEFLAGS were added

.PHONY: build $(patsubst %,build-%,$(TARGETS)) install
