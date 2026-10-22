# Makefile for the scripts/ sub-directory

# Here, we can update the config.* scripts.
# If we're in CT_LIB_DIR, then CT_LIB_DIR == CT_TOP_DIR, and we can update those
# scripts for later inclusion mainline. If CT_LIB_DIR != CT_TOP_DIR, then those
# scripts are downloaded only for use in CT_TOP_DIR.

# ----------------------------------------------------------
# The tools help entry

help-distrib::
	@echo  '  updatetools        - Update the config tools'

# ----------------------------------------------------------
# Where to get tools from, and where to store them into
# The tools are: config.guess and config.sub

CONFIG_GIT_SRC=https://git.savannah.gnu.org/git/config.git
CONFIG_SUB_DEST=scripts/config.sub
CONFIG_GUESS_DEST=scripts/config.guess

PHONY += updatetools
updatetools: scripts FORCE
	@$(CT_ECHO) '  UPDATE    config.guess and config.sub'
	$(SILENT)if [ -z "$(git)" ]; then \
	    echo "git is needed for updatetools, but was not found by ./configure" >&2; \
	    exit 1; \
	fi
	$(SILENT)tmp_dir=`mktemp -d`; \
	trap 'rm -rf "$${tmp_dir}"' EXIT; \
	$(git) clone --quiet --depth 1 $(CONFIG_GIT_SRC) "$${tmp_dir}/config" && \
	cp "$${tmp_dir}/config/config.sub" $(CONFIG_SUB_DEST) && \
	cp "$${tmp_dir}/config/config.guess" $(CONFIG_GUESS_DEST) && \
	chmod u+rwx,go+rx-w $(CONFIG_SUB_DEST) $(CONFIG_GUESS_DEST)

PHONY += scripts
scripts:
	@$(CT_ECHO) '  MKDIR $@'
	$(SILENT)mkdir -p $@

# ----------------------------------------------------------
# Clean up the mess

distclean::
	@$(CT_ECHO) "  CLEAN scripts"
	$(SILENT)[ $(CT_TOP_DIR) = $(CT_LIB_DIR) ] || rm -rf $(CT_TOP_DIR)/scripts
