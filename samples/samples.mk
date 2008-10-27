# Makefile to manage samples

# ----------------------------------------------------------
# Build the list of available samples
CT_TOP_SAMPLES := $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config))
CT_LIB_SAMPLES := $(filter-out $(CT_TOP_SAMPLES),$(patsubst $(CT_LIB_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_LIB_DIR)/samples/*/crosstool.config)))
CT_SAMPLES := $(sort $(CT_TOP_SAMPLES) $(CT_LIB_SAMPLES))

# ----------------------------------------------------------
# This part deals with the samples help entries

help-config::
	@echo  '  saveconfig         - Save current config as a preconfigured target'

help-samples::
	@echo  '  list-samples       - prints the list of all samples (for scripting)'
	@echo  '  show-<sample>      - show a brief overview of <sample> (list below)'
	@echo  '  <sample>           - preconfigure crosstool-NG with <sample> (list below)'
	@$(CT_LIB_DIR)/scripts/showSamples.sh $(CT_SAMPLES)

help-build::
	@echo  '  regtest[.#]        - Regtest-build all samples'
	@echo  '  regtest-local[.#]  - Regtest-build all local samples'
	@echo  '  regtest-global[.#] - Regtest-build all global samples'

help-distrib::
	@echo  '  wiki-samples       - Print a DokuWiki table of samples'

# ----------------------------------------------------------
# This part deals with printing samples information

# Prints the details of a sample
PHONY += $(patsubst %,show-%,$(CT_SAMPLES))
$(patsubst %,show-%,$(CT_SAMPLES)):
	@$(CT_LIB_DIR)/scripts/showSamples.sh -v $(patsubst show-%,%,$(@))

# print the list of all available samples
PHONY += list-samples
list-samples: .FORCE
	@echo $(CT_SAMPLES) |sed -r -e 's/ /\n/g;' |sort

wiki-samples:
	$(SILENT)$(CT_LIB_DIR)/scripts/showSamples.sh -w $(CT_SAMPLES)

# ----------------------------------------------------------
# This part deals with saving/restoring samples

# Save a sample
saveconfig:
	$(SILENT)$(CT_LIB_DIR)/scripts/saveSample.sh

# The 'sample_dir' function prints the directory in which the sample is,
# searching first in local samples, then in global samples
define sample_dir
$$( [ -d $(CT_TOP_DIR)/samples/$(1) ] && echo "$(CT_TOP_DIR)/samples/$(1)" || echo "$(CT_LIB_DIR)/samples/$(1)")
endef

# How we do recall one sample
PHONY += $(CT_SAMPLES)
$(CT_SAMPLES):
	$(SILENT)cp $(call sample_dir,$@)/crosstool.config .config
	$(SILENT)$(MAKE) -rf $(CT_NG) oldconfig
	@echo
	@echo  '***********************************************************'
	@echo
	$(SILENT)( . $(call sample_dir,$@)/reported.by;                             \
	   echo "Initially reported by: $${reporter_name:-Yann E. MORIN}";          \
	   echo "URL: $${reporter_url:-http://ymorin.is-a-geek.org/}";              \
	   if [ -n "$${reporter_comment}" ]; then                                   \
	     echo  ;                                                                \
	     echo  "Comment:";                                                      \
	     printf "$${reporter_comment}\n";                                       \
	   fi;                                                                      \
	   echo  ;                                                                  \
	   echo  '***********************************************************';     \
	 )
	$(SILENT)if grep -E '^CT_EXPERIMENTAL=y$$' .config >/dev/null 2>&1; then    \
	   echo  ;                                                                  \
	   echo  'WARNING! This sample may enable experimental features.';          \
	   echo  '         Please be sure to review the configuration prior';       \
	   echo  '         to building and using your toolchain!';                  \
	   echo  'Now, you have been warned!';                                      \
	   echo  ;                                                                  \
	   echo  '***********************************************************';     \
	 fi
	@echo
	@echo  'Now configured for "$@"'

# ----------------------------------------------------------
# And now for building all samples one after the other

PHONY += regtest regtest_local regtest_global
regtest: regtest-local regtest-global

regtest-local: $(patsubst %,regtest_%,$(CT_TOP_SAMPLES))

regtest-global: $(patsubst %,regtest_%,$(CT_LIB_SAMPLES))

regtest.% regtest-local.% regtest-global.%:
	$(SILENT)$(CT_NG) $(shell echo "$(@)" |sed -r -e 's|^([^.]+)\.([[:digit:]]+)$$|\1 CT_JOBS=\2|;')

# One regtest per sample
# We could use a simple rule like: 'regtest: $(CT_SAMPLES)', but that doesn't
# work because we want to save the samples as well.
# Also, we don't want to see anylog at all, save for the elapsed time, and we
# want to save the log file in a specific place
# Furthermore, force the location where the toolchain will be installed.
# Finaly, we can't use 'make sample-name' as we need to provide default values
# if the options set has changed, but oldconfig does not like when stdin is
# not a terminal (eg. it is a pipe).
$(patsubst %,regtest_%,$(CT_SAMPLES)):
	$(SILENT)samp=$(patsubst regtest_%,%,$@)                                                        ;   \
	 echo -e "\rBuilding sample \"$${samp}\""                                                       &&  \
	 $(CT_NG) copy_config_$${samp}                                                                  &&  \
	 yes "" |$(CT_NG) defoldconfig >/dev/null 2>&1                                                  &&  \
	 sed -i -r -e 's:^(CT_PREFIX_DIR=).*$$:\1"$${CT_TOP_DIR}/targets/tst/$${CT_TARGET}":;' .config  &&  \
	 sed -i -r -e 's:^.*(CT_LOG_(WARN|INFO|EXTRA|DEBUG|ALL)).*$$:# \1 is not set:;' .config         &&  \
	 sed -i -r -e 's:^.*(CT_LOG_ERROR).*$$:\1=y:;' .config                                          &&  \
	 sed -i -r -e 's:^(CT_LOG_LEVEL_MAX)=.*$$:\1="ERROR":;' .config                                 &&  \
	 sed -i -r -e 's:^.*(CT_LOG_TO_FILE).*$$:\1=y:;' .config                                        &&  \
	 sed -i -r -e 's:^.*(CT_LOG_PROGRESS_BAR).*$$:\1=y:;' .config                                   &&  \
	 yes "" |$(CT_NG) defoldconfig >/dev/null 2>&1                                                  &&  \
	 $(CT_NG) build                                                                                 &&  \
	 echo -e "\rSuccessfully built sample \"$${samp}\""                                             &&  \
	 echo -e "\rMaking tarball for sample \"$${samp}\""                                             &&  \
	 $(CT_NG) tarball                                                                               &&  \
	 echo -e "\rSuccessfully built tarball for sample \"$${samp}\""                                 ;   \
	 echo -e "\rCleaning sample \"$${samp}\""                                                       ;   \
	 $(CT_NG) distclean                                                                             ;   \
	 echo -e "\r"
