APP_NAME := Strafe
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR := $(APP_BUNDLE)/Contents/MacOS
RES_DIR := $(APP_BUNDLE)/Contents/Resources
FRAMEWORKS_DIR := $(APP_BUNDLE)/Contents/Frameworks
INFO_PLIST := Resources/Info.plist
CONFIG ?= debug
BINARY_PATH = $(firstword $(wildcard .build/$(CONFIG)/$(APP_NAME) .build/*/$(CONFIG)/$(APP_NAME)))
FRAMEWORK_NAME := OpenMultitouchSupportXCF.framework
FRAMEWORK_PATH = $(firstword $(wildcard .build/$(CONFIG)/$(FRAMEWORK_NAME) .build/*/$(CONFIG)/$(FRAMEWORK_NAME)))

.PHONY: build run clean

build:
	@mkdir -p $(MACOS_DIR) $(RES_DIR) $(FRAMEWORKS_DIR)
	@cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	swift build -c $(CONFIG)
	@if [ -z "$(BINARY_PATH)" ]; then \
		echo "Error: build product not found in .build. Try: swift build -c $(CONFIG) --show-bin-path"; \
		exit 1; \
	fi
	@cp $(BINARY_PATH) $(MACOS_DIR)/$(APP_NAME)
	@if [ -z "$(FRAMEWORK_PATH)" ]; then \
		echo "Error: $(FRAMEWORK_NAME) not found in .build. Try: swift build -c $(CONFIG) --show-bin-path"; \
		exit 1; \
	fi
	@rm -rf $(FRAMEWORKS_DIR)/$(FRAMEWORK_NAME)
	@ditto $(FRAMEWORK_PATH) $(FRAMEWORKS_DIR)/$(FRAMEWORK_NAME)
	@if ! otool -l $(MACOS_DIR)/$(APP_NAME) | rg -q "@executable_path/../Frameworks"; then \
		install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/$(APP_NAME); \
	fi
	@codesign --force --deep --sign - $(APP_BUNDLE) >/dev/null

run: build
	@open $(APP_BUNDLE)

clean:
	@rm -rf $(BUILD_DIR)
