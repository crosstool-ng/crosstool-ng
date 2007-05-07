# Build a list of all available samples

SAMPLES = $(patsubst $(CT_TOP_DIR)/samples/%,%,$(filter-out %Makefile,$(wildcard $(CT_TOP_DIR)/samples/*)))
.PHONY: $(SAMPLES)
$(SAMPLES):
	@cp "$(CT_TOP_DIR)/samples/$(@)/crosstool.config" "$(CT_TOP_DIR)/.config"
	@$(MAKE) oldconfig

help::
	@echo  'Preconfigured targets:'
	@for s in $(SAMPLES); do   \
	    echo  "  $${s}"; \
	 done
	@echo  ''

saveconfig:
	@$(CT_TOP_DIR)/scripts/saveSample.sh
