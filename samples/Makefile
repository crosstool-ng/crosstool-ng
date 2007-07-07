# Makefile to manage samples

# Build the list of available samples
CT_TOP_SAMPLES := $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config))
CT_LIB_SAMPLES := $(filter-out $(CT_TOP_SAMPLES),$(patsubst $(CT_LIB_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_LIB_DIR)/samples/*/crosstool.config)))

CT_SAMPLES := $(CT_TOP_SAMPLES) $(CT_LIB_SAMPLES)

help-config::
	@echo  '  saveconfig     - Save current config as a preconfigured target'

help-samples::
	@$(CT_LIB_DIR)/scripts/showSamples.sh $(CT_SAMPLES)

help-build::
	@echo  '  regtest        - Regtest-build all samples'

# How we do build one sample
PHONY += $(CT_SAMPLES)
$(CT_SAMPLES):
	@$(MAKE) -f $(CT_MAKEFILE) $(patsubst %,%_copy_config,$(@)) oldconfig

$(patsubst %,%_copy_config,$(CT_SAMPLES)):
	@if [ -f $(CT_TOP_DIR)/samples/$(patsubst %_copy_config,%,$(@))/crosstool.config ]; then                    \
	      cp "$(CT_TOP_DIR)/samples/$(patsubst %_copy_config,%,$(@))/crosstool.config" "$(CT_TOP_DIR)/.config"; \
	 else                                                                                                       \
	      cp "$(CT_LIB_DIR)/samples/$(patsubst %_copy_config,%,$(@))/crosstool.config" "$(CT_TOP_DIR)/.config"; \
	 fi

# And now for building all samples one after the other
# We could use a simple rule like: 'regtest: $(CT_SAMPLES)', but that doesn't
# work because we want to save the samples as well.
# Also, we don't want to see anylog at all, save for the elapsed time, and we
# want to save the log file in a specific place
# Furthermore, force the location where the toolchain will be installed.
# Finaly, we can't use 'make sample-name' as we need to provide default values
# if the options set has changed, but oldconfig does not like when stdin is
# not a terminal (eg. it is a pipe).
PHONY += regtest
regtest:
	@for samp in $(CT_SAMPLES); do                                                                          \
	     echo -e "\rBuilding sample \"$${samp}\""                                                       &&  \
	     $(CT_NG) $${samp}_copy_config                                                                  &&  \
	     yes "" |$(CT_NG) defoldconfig >/dev/null 2>&1                                                  &&  \
	     sed -i -r -e 's:^(CT_PREFIX_DIR=).*$$:\1"$${CT_TOP_DIR}/targets/tst/$${CT_TARGET}":;' .config  &&  \
	     sed -i -r -e 's:^.*(CT_LOG_(WARN|INFO|EXTRA|DEBUG|ALL)).*$$:# \1 is not set:;' .config         &&  \
	     sed -i -r -e 's:^.*(CT_LOG_ERROR).*$$:\1=y:;' .config                                          &&  \
	     sed -i -r -e 's:^(CT_LOG_LEVEL_MAX)=.*$$:\1="ERROR":;' .config                                 &&  \
	     sed -i -r -e 's:^.*(CT_LOG_TO_FILE).*$$:\1=y:;' .config                                        &&  \
	     sed -i -r -e 's:^.*(CT_LOG_PROGRESS_BAR).*$$:\1=y:;' .config                                   &&  \
	     yes "" |$(CT_NG) defoldconfig >/dev/null 2>&1                                                  &&  \
	     $(CT_NG) build                                                                                 &&  \
	     echo -e "\rMaking tarball for sample \"$${samp}\""                                             &&  \
	     $(CT_NG) tarball                                                                               ;   \
	     echo -e "\rCleaning sample \"$${samp}\""                                                       ;   \
	     $(CT_NG) distclean                                                                             ;   \
	 done

saveconfig:
	@$(CT_LIB_DIR)/scripts/saveSample.sh
