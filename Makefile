PREFIX ?= ~/.local
APP_NAME = PowerMonitor
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = $(PREFIX)/bin
PLIST_DIR = ~/Library/LaunchAgents
PLIST_LABEL = com.user.power-monitor

.PHONY: build install uninstall launchd-install launchd-uninstall clean

build:
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	swiftc -parse-as-library \
		-framework Cocoa \
		-framework IOKit \
		-framework UserNotifications \
		-O \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		$(APP_NAME).swift
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist

install: build
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "Run: open -a $(INSTALL_DIR)/$(APP_BUNDLE)"

uninstall:
	rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "Removed $(INSTALL_DIR)/$(APP_BUNDLE)"

launchd-install: install
	@sed 's|__APP_PATH__|$(INSTALL_DIR)/$(APP_BUNDLE)|g' com.user.power-monitor.plist > $(PLIST_DIR)/$(PLIST_LABEL).plist
	launchctl load $(PLIST_DIR)/$(PLIST_LABEL).plist
	@echo "LaunchAgent installed and loaded"

launchd-uninstall:
	-launchctl unload $(PLIST_DIR)/$(PLIST_LABEL).plist 2>/dev/null
	rm -f $(PLIST_DIR)/$(PLIST_LABEL).plist
	@echo "LaunchAgent removed"

clean:
	rm -rf $(APP_BUNDLE)
