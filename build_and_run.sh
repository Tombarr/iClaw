#!/bin/bash
set -e

APP_NAME="iClaw"
BUILD_DIR=".build/debug"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swift build

echo "Packaging $APP_NAME.app..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>$APP_NAME needs microphone access to hear you.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>$APP_NAME needs speech recognition to understand you.</string>
    <key>NSContactsUsageDescription</key>
    <string>$APP_NAME needs contacts access to personalize responses.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>$APP_NAME needs calendar access to manage events.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>$APP_NAME needs to control Messages.</string>
</dict>
</plist>
EOF

echo "Done! You can run the app with:"
echo "open $APP_DIR"
