APP_NAME := Strafe
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
MACOS_DIR := $(APP_BUNDLE)/Contents/MacOS
RES_DIR := $(APP_BUNDLE)/Contents/Resources
FRAMEWORKS_DIR := $(APP_BUNDLE)/Contents/Frameworks
INFO_PLIST := Resources/Info.plist
CONFIG ?= debug
FRAMEWORK_NAME := OpenMultitouchSupportXCF.framework
ARTIFACT_DIR := .build/artifacts/openmultitouchsupport/OpenMultitouchSupportXCF
ARTIFACT_INFO := $(ARTIFACT_DIR)/OpenMultitouchSupportXCF.xcframework/Info.plist

.PHONY: build run clean

build:
	@mkdir -p $(MACOS_DIR) $(RES_DIR) $(FRAMEWORKS_DIR)
	@cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	@for icon in $(wildcard Resources/*.icns); do \
		cp "$$icon" $(RES_DIR)/; \
	done
	@if [ -d "$(ARTIFACT_DIR)" ] && [ ! -f "$(ARTIFACT_INFO)" ]; then \
		echo "Cleaning incomplete OpenMultitouchSupport artifact..."; \
		rm -rf "$(ARTIFACT_DIR)"; \
	fi
	@BIN_DIR=$$(swift build -c $(CONFIG) --show-bin-path); \
	if [ -z "$$BIN_DIR" ]; then \
		echo "Error: build output path not found. Try: swift build -c $(CONFIG) --show-bin-path"; \
		exit 1; \
	fi; \
	BINARY_PATH="$$BIN_DIR/$(APP_NAME)"; \
	if [ ! -f "$$BINARY_PATH" ]; then \
		echo "Error: build product not found at $$BINARY_PATH"; \
		exit 1; \
	fi; \
	FRAMEWORK_PATH="$$BIN_DIR/$(FRAMEWORK_NAME)"; \
	if [ ! -d "$$FRAMEWORK_PATH" ]; then \
		echo "Error: $(FRAMEWORK_NAME) not found at $$FRAMEWORK_PATH"; \
		exit 1; \
	fi; \
	cp "$$BINARY_PATH" $(MACOS_DIR)/$(APP_NAME); \
	rm -rf $(FRAMEWORKS_DIR)/$(FRAMEWORK_NAME); \
	ditto "$$FRAMEWORK_PATH" $(FRAMEWORKS_DIR)/$(FRAMEWORK_NAME)
	@if ! otool -l $(MACOS_DIR)/$(APP_NAME) | rg -q "@executable_path/../Frameworks"; then \
		install_name_tool -add_rpath @executable_path/../Frameworks $(MACOS_DIR)/$(APP_NAME); \
	fi
	@codesign --force --deep --sign - $(APP_BUNDLE) >/dev/null

run: build
	@open $(APP_BUNDLE)

clean:
	@rm -rf $(BUILD_DIR)
