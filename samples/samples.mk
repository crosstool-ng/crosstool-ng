# Makefile to manage samples

# ----------------------------------------------------------
# Build the list of available samples
CT_TOP_SAMPLES := $(patsubst $(CT_TOP_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_TOP_DIR)/samples/*/crosstool.config))
CT_LIB_SAMPLES := $(filter-out $(CT_TOP_SAMPLES),$(patsubst $(CT_LIB_DIR)/samples/%/crosstool.config,%,$(wildcard $(CT_LIB_DIR)/samples/*/crosstool.config)))
CT_SAMPLES := $(shell echo $(sort $(CT_TOP_SAMPLES) $(CT_LIB_SAMPLES))  \
                      |$(sed) -r -e 's/ /\n/g;'                         \
                      |$(sed) -r -e 's/(.*),(.*)/\2,\1/;'               \
                      |sort                                             \
                      |$(sed) -r -e 's/(.*),(.*)/\2,\1/;'               \
               )

# ----------------------------------------------------------
# This part deals with the samples help entries

help-config::
	@echo  '  saveconfig         - Save current config as a preconfigured target'

help-samples::
	@echo  '  list-samples       - prints the list of all samples (for scripting)'
	@echo  '  show-<sample>      - show a brief overview of <sample> (list with list-samples)'
	@echo  '  <sample>           - preconfigure crosstool-NG with <sample> (list with list-samples)'
	@echo  '  build-all[.#]      - Build *all* samples (list with list-samples) and install in'
	@echo  '                       $${CT_PREFIX} (which you must set)'

help-distrib::
	@echo  '  wiki-samples       - Print a DokuWiki table of samples'

help-env::
	@echo  '  CT_PREFIX=dir      - install samples in dir (see action "build-all", above).'

# ----------------------------------------------------------
# This part deals with printing samples information

# Print the details of current configuration
PHONY += show-config
show-config: .config
	@cp .config .config.sample
	@$(CT_LIB_DIR)/scripts/showSamples.sh -v current
	@rm -f .config.sample

# Prints the details of a sample
PHONY += $(patsubst %,show-%,$(CT_SAMPLES))
$(patsubst %,show-%,$(CT_SAMPLES)): config_files
	@KCONFIG_CONFIG=$$(pwd)/.config.sample	\
	    $(CONF) --defconfig=$(call sample_dir,$(patsubst show-%,%,$(@)))/crosstool.config   \
	            $(KCONFIG_TOP) >/dev/null
	@$(CT_LIB_DIR)/scripts/showSamples.sh -v $(patsubst show-%,%,$(@))
	@rm -f .config.sample

# Prints the details of all samples
PHONY += show-all
show-all: $(patsubst %,show-%,$(CT_SAMPLES))

# print the list of all available samples
PHONY += list-samples
list-samples: list-samples-pre $(patsubst %,list-%,$(CT_SAMPLES))
	@echo ' L (Local)       : sample was found in current directory'
	@echo ' G (Global)      : sample was installed with crosstool-NG'
	@echo ' X (EXPERIMENTAL): sample may use EXPERIMENTAL features'
	@echo ' B (BROKEN)      : sample is currently broken'

PHONY += list-samples-pre
list-samples-pre: FORCE
	@echo 'Status  Sample name'

PHONY += $(patsubst %,list-%,$(CT_SAMPLES))
$(patsubst %,list-%,$(CT_SAMPLES)): config_files
	@KCONFIG_CONFIG=$$(pwd)/.config.sample	\
	    $(CONF) --defconfig=$(call sample_dir,$(patsubst list-%,%,$(@)))/crosstool.config   \
	            $(KCONFIG_TOP) >/dev/null
	@$(CT_LIB_DIR)/scripts/showSamples.sh $(patsubst list-%,%,$(@))
	@rm -f .config.sample

PHONY += list-samples-short
list-samples-short: FORCE
	$(SILENT)for s in $(CT_SAMPLES); do \
	    printf "%s\n" "$${s}";          \
	done

PHONY += wiki-samples
wiki-samples: wiki-samples-pre $(patsubst %,wiki-%,$(CT_SAMPLES)) wiki-samples-post

wiki-samples-pre: FORCE
	$(SILENT)$(CT_LIB_DIR)/scripts/showSamples.sh -w

wiki-samples-post: FORCE
	$(SILENT)$(CT_LIB_DIR)/scripts/showSamples.sh -W $(CT_SAMPLES)

$(patsubst %,wiki-%,$(CT_SAMPLES)): config_files
	$(SILENT)KCONFIG_CONFIG=$$(pwd)/.config.sample	\
	    $(CONF) --defconfig=$(call sample_dir,$(patsubst wiki-%,%,$(@)))/crosstool.config   \
	            $(KCONFIG_TOP) >/dev/null
	$(SILENT)$(CT_LIB_DIR)/scripts/showSamples.sh -w $(patsubst wiki-%,%,$(@))
	$(SILENT)rm -f .config.sample

# ----------------------------------------------------------
# This part deals with saving/restoring samples

PHONY += samples
samples:
	@$(ECHO) '  MKDIR $@'
	$(SILENT)mkdir -p $@

# Save a sample
saveconfig: .config samples
	$(SILENT)$(CT_LIB_DIR)/scripts/saveSample.sh

# The 'sample_dir' function prints the directory in which the sample is,
# searching first in local samples, then in global samples
define sample_dir
$$( [ -d $(CT_TOP_DIR)/samples/$(1) ] && echo "$(CT_TOP_DIR)/samples/$(1)" || echo "$(CT_LIB_DIR)/samples/$(1)")
endef

# How we do recall one sample
PHONY += $(CT_SAMPLES)
$(CT_SAMPLES): config_files
	@$(ECHO) "  CONF  $(KCONFIG_TOP)"
	$(SILENT)$(CONF) --defconfig=$(call sample_dir,$@)/crosstool.config $(KCONFIG_TOP)
	@echo
	@echo  '***********************************************************'
	@echo
	$(SILENT)( . $(call sample_dir,$@)/reported.by;                             \
	   echo "Initially reported by: $${reporter_name}";                         \
	   echo "URL: $${reporter_url}";                                            \
	   if [ -n "$${reporter_comment}" ]; then                                   \
	     echo  ;                                                                \
	     echo  "Comment:";                                                      \
	     printf "$${reporter_comment}\n";                                       \
	   fi;                                                                      \
	   echo  ;                                                                  \
	   echo  '***********************************************************';     \
	 )
	$(SILENT)if $(grep) -E '^CT_EXPERIMENTAL=y$$' .config >/dev/null 2>&1; then \
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
# Some helper functions

# Create the rule to build a sample
# $1: sample tuple
# $2: prefix
define build_sample
	@$(ECHO) '  CONF  $(1)'
	$(SILENT)cp $(call sample_dir,$(1))/crosstool.config .config
	$(SILENT)$(sed) -i -r -e 's:^(CT_PREFIX_DIR=).*$$:\1"$(2)":;' .config
	$(SILENT)$(sed) -i -r -e 's:^.*(CT_LOG_(WARN|INFO|EXTRA|DEBUG|ALL)).*$$:# \1 is not set:;' .config
	$(SILENT)$(sed) -i -r -e 's:^.*(CT_LOG_ERROR).*$$:\1=y:;' .config
	$(SILENT)$(sed) -i -r -e 's:^(CT_LOG_LEVEL_MAX)=.*$$:\1="ERROR":;' .config
	$(SILENT)$(sed) -i -r -e 's:^.*(CT_LOG_TO_FILE).*$$:\1=y:;' .config
	$(SILENT)$(sed) -i -r -e 's:^.*(CT_LOG_PROGRESS_BAR).*$$:\1=y:;' .config
	$(SILENT)$(MAKE) -rf $(CT_NG) V=0 oldconfig
	@$(ECHO) '  BUILD $(1)'
	$(SILENT)$(MAKE) -rf $(CT_NG) V=0 build
endef

# ----------------------------------------------------------
# Build samples for use (not regtest!)

# Check that PREFIX is set if building samples
ifneq ($(strip $(MAKECMDGOALS)),)
ifneq ($(strip $(filter $(patsubst %,build-%,$(CT_SAMPLES)) build-all,$(MAKECMDGOALS))),)

ifeq ($(strip $(CT_PREFIX)),)
$(error Please set 'CT_PREFIX' to where you want to install generated toolchain samples!)
endif

endif # MAKECMDGOALS contains a build sample rule
endif # MAKECMDGOALS != ""

# Build a single sample
$(patsubst %,build-%,$(CT_SAMPLES)):
	$(call build_sample,$(patsubst build-%,%,$@),$(CT_PREFIX)/$(patsubst build-%,%,$@))

# Build al samples
build-all: $(patsubst %,build-%,$(CT_SAMPLES))

# Build all samples, overiding the number of // jobs per sample
build-all.%:
	$(SILENT)$(MAKE) -rf $(CT_NG) V=$(V) $(shell echo "$(@)" |$(sed) -r -e 's|^([^.]+)\.([[:digit:]]+)$$|\1 CT_JOBS=\2|;')

