# Makefile to manage samples

# Build the list of available samples
CT_SAMPLES = $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config))

help::
	@echo  'Preconfigured targets:'
	@$(CT_TOP_DIR)/scripts/showSamples.sh $(CT_SAMPLES)
	@echo  ''

# How we do build one sample
.PHONY: $(CT_SAMPLES)
$(CT_SAMPLES):
	@cp "$(CT_TOP_DIR)/samples/$(@)/crosstool.config" "$(CT_TOP_DIR)/.config"
	@$(MAKE) oldconfig

# And now for building all samples one after the other
# We could use a simple rule like: 'regtest: $(CT_SAMPLES)', but that doesn't
# work because we want to save the samples as well.
# Also, we don't want to see anylog at all, save for the elapsed time, and we
# want to save the log file in a specific place
# Furthermore, force the location where the toolchain will be installed.
# Finaly, we can't use 'make sample-name' as we need to provide default values
# if the options set has changed, but oldconfig does not like when stdin is
# not a terminal (eg. it is a pipe).
.PHONY: regtest
regtest:
	@for samp in $(CT_SAMPLES); do                                                                          \
	     echo "Building sample \"$${samp}\""                                                            &&  \
	     cp "$(CT_TOP_DIR)/samples/$${samp}/crosstool.config" "$(CT_TOP_DIR)/.config"                   &&  \
	     yes "" |make -C $(CT_TOP_DIR) defoldconfig >/dev/null 2>&1                                     &&  \
	     sed -i -r -e 's:^(CT_PREFIX_DIR=).*$$:\1"${CT_TOP_DIR}/targets/tst/$${CT_TARGET}":;' .config   &&  \
	     sed -i -r -e 's:^.*(CT_LOG_(WARN|INFO|EXTRA|DEBUG|ALL)).*$$:# \1 is not set:;' .config         &&  \
	     sed -i -r -e 's:^.*(CT_LOG_ERROR).*$$:\1=y:;' .config                                          &&  \
	     sed -i -r -e 's:^(CT_LOG_LEVEL_MAX)=.*$$:\1="ERROR":;' .config                                 &&  \
	     sed -i -r -e 's:^.*(CT_LOG_TO_FILE).*$$:\1=y:;' .config                                        &&  \
	     sed -i -r -e 's:^.*(CT_LOG_FILE).*$$:\1="$${CT_PREFIX_DIR}/build.log":;' .config               &&  \
	     sed -i -r -e 's:^.*(CT_LOG_PROGRESS_BAR).*$$:\1=y:;' .config                                   &&  \
	     yes "" |make -C $(CT_TOP_DIR) defoldconfig >/dev/null 2>&1                                     &&  \
	     make -C $(CT_TOP_DIR)                                                                          &&  \
	     make -C $(CT_TOP_DIR) tarball                                                                  &&  \
	     chmod -R u+w $(CT_TOP_DIR)/targets                                                             &&  \
	     rm -rf $(CT_TOP_DIR)/targets;                                                                      \
	 done
	@make distclean

saveconfig:
	$(CT_TOP_DIR)/scripts/saveSample.sh
