# Build a list of all available samples

CT_SAMPLES = $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(filter-out %Makefile,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config)))
.PHONY: $(SAMPLES)
$(CT_SAMPLES):
	@cp "$(CT_TOP_DIR)/samples/$(@)/crosstool.config" "$(CT_TOP_DIR)/.config"
	@$(MAKE) oldconfig

help::
	@echo  'Preconfigured targets:'
	@$(CT_TOP_DIR)/scripts/showSamples.sh $(CT_SAMPLES)
	@echo  ''

saveconfig:
	@$(CT_TOP_DIR)/scripts/saveSample.sh
