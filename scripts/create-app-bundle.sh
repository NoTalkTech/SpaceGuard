#!/bin/bash

# Create SpaceGuard.app bundle from SwiftPM build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="SpaceGuard"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
RESOURCES_DIR="$PROJECT_DIR/Sources/Resources"

# Determine build directory (universal binary may be in different location)
if [ -f "$PROJECT_DIR/.build/apple/Products/Release/$APP_NAME" ]; then
    BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
elif [ -f "$PROJECT_DIR/.build/release/$APP_NAME" ]; then
    BUILD_DIR="$PROJECT_DIR/.build/release"
else
    echo "Error: $APP_NAME executable not found"
    echo "Please build the project first: swift build --configuration release"
    exit 1
fi

echo "Creating $APP_NAME.app bundle..."

# Clean up existing bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy icon if exists
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    ICON_FILE="AppIcon.icns"
else
    ICON_FILE=""
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.notalktech.SpaceGuard</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 NoTalkTech. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
EOF

if [ -n "$ICON_FILE" ]; then
    cat >> "$APP_BUNDLE/Contents/Info.plist" << EOF
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
EOF
fi

cat >> "$APP_BUNDLE/Contents/Info.plist" << EOF
</dict>
</plist>
EOF

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Created $APP_BUNDLE"
echo "Bundle size: $(du -sh "$APP_BUNDLE" | cut -f1)"