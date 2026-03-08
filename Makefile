APP_BUNDLE = .build/arm64-apple-macosx/debug/iClaw.app
RESOURCES   = $(APP_BUNDLE)/Contents/Resources
ICON_SRC    = iClaw.icon
ICON_BUILD  = .build/icon

.PHONY: build run clean icon

build: icon
	swift build
	@mkdir -p $(RESOURCES)
	@cp -f $(ICON_BUILD)/Assets.car $(RESOURCES)/Assets.car
	@cp -f $(ICON_BUILD)/iClaw.icns $(RESOURCES)/iClaw.icns
	@echo "Build complete with app icon."

icon: $(ICON_BUILD)/Assets.car

$(ICON_BUILD)/Assets.car: $(ICON_SRC)/icon.json $(ICON_SRC)/Assets/appleclaw.png
	@mkdir -p $(ICON_BUILD)
	xcrun actool $(ICON_SRC) --compile $(ICON_BUILD) \
		--output-format human-readable-text --notices --warnings --errors \
		--output-partial-info-plist $(ICON_BUILD)/temp.plist \
		--app-icon iClaw --include-all-app-icons \
		--enable-on-demand-resources NO --development-region en \
		--target-device mac --minimum-deployment-target 26.0 --platform macosx

run: build
	open $(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(ICON_BUILD)
