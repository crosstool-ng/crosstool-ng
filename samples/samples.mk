# Makefile to manage samples

# Build the list of available samples
CT_TOP_SAMPLES := $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config))
CT_LIB_SAMPLES := $(filter-out $(CT_TOP_SAMPLES),$(patsubst $(CT_LIB_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_LIB_DIR)/samples/*/crosstool.config)))

CT_SAMPLES := $(CT_TOP_SAMPLES) $(CT_LIB_SAMPLES)

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

$(patsubst %,show-%,$(CT_SAMPLES)):
	@$(CT_LIB_DIR)/scripts/showSamples.sh -v $(patsubst show-%,%,$(@))

PHONY += list-samples
list-samples: .FORCE
	@echo $(CT_SAMPLES) |sed -r -e 's/ /\n/g;' |sort

# How we do build one sample
PHONY += $(CT_SAMPLES)
$(CT_SAMPLES):
	@echo  'Configuring for "$@"'
	@$(CT_NG) $(patsubst %,copy_config_%,$(@)) oldconfig
	@echo  'Execute "$(CT_NG) build" to build your toolchain'

$(patsubst %,copy_config_%,$(CT_SAMPLES)):
	@if [ -f $(CT_TOP_DIR)/samples/$(patsubst copy_config_%,%,$(@))/crosstool.config ]; then                    \
	      cp "$(CT_TOP_DIR)/samples/$(patsubst copy_config_%,%,$(@))/crosstool.config" "$(CT_TOP_DIR)/.config"; \
	 else                                                                                                       \
	      cp "$(CT_LIB_DIR)/samples/$(patsubst copy_config_%,%,$(@))/crosstool.config" "$(CT_TOP_DIR)/.config"; \
	 fi

# And now for building all samples one after the other
PHONY += regtest regtest_local regtest_global
regtest: regtest-local regtest-global

regtest-local: $(patsubst %,regtest_%,$(CT_TOP_SAMPLES))

regtest-global: $(patsubst %,regtest_%,$(CT_LIB_SAMPLES))

regtest.% regtest-local.% regtest-global.%:
	@$(CT_NG) $(shell echo "$(@)" |sed -r -e 's|^([^.]+)\.([[:digit:]]+)$$|\1 CT_JOBS=\2|;')

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
	@samp=$(patsubst regtest_%,%,$@)                                                                ;   \
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

saveconfig:
	@$(CT_LIB_DIR)/scripts/saveSample.sh

wiki-samples:
	@$(CT_LIB_DIR)/scripts/showSamples.sh -w $(CT_SAMPLES)
