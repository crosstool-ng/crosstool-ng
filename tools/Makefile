CONFIG_SUB_SRC="http://cvs.savannah.gnu.org/viewcvs/*checkout*/config/config/config.sub"
CONFIG_SUB_DEST="$(CT_TOP_DIR)/tools/config.sub"
CONFIG_GUESS_SRC="http://cvs.savannah.gnu.org/viewcvs/*checkout*/config/config/config.guess"
CONFIG_GUESS_DEST="$(CT_TOP_DIR)/tools/config.guess"

updatetools:
	@wget "$(CONFIG_SUB_SRC)" -O "$(CONFIG_SUB_DEST)"
	@wget "$(CONFIG_GUESS_SRC)" -O "$(CONFIG_GUESS_DEST)"

help::
	@echo  '  updatetools    - Update the config tools'
	@echo  ''
