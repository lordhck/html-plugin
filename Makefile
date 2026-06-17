PLUGIN_NAME := html
PLUGIN_FILE := html.lua

CONFIG_DIR := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)
PLUG_DIR   := $(CONFIG_DIR)/micro/plug
DEST       := $(PLUG_DIR)/$(PLUGIN_NAME)

INSTALL_FILES := $(PLUGIN_FILE) repo.json

.PHONY: install uninstall reinstall

install:
	@echo -n "Installing '$(PLUGIN_NAME)' plugin ... "
	@mkdir -p $(DEST)
	@cp $(INSTALL_FILES) $(DEST)/
	@echo "Installed."

uninstall:
	@echo -n "Removing '$(PLUGIN_NAME)' plugin  ... "
	@rm -rf $(DEST)
	@echo "Removed."

reinstall: uninstall install
