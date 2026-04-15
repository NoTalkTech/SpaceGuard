#!/bin/bash

# Create SpaceGuard.app bundle from SwiftPM build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="SpaceGuard"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
RESOURCES_DIR="$PROJECT_DIR/Sources/Resources"
APP_VERSION="${SPACEGUARD_VERSION:-${VERSION:-}}"

if [ -z "$APP_VERSION" ] && command -v git >/dev/null 2>&1; then
    APP_VERSION="$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
fi

if [ -z "$APP_VERSION" ]; then
    APP_VERSION="1.0"
fi

# Allow CI to point packaging at a dedicated scratch build root.
if [ -n "${SPACEGUARD_BUILD_DIR:-}" ]; then
    BUILD_DIR="$SPACEGUARD_BUILD_DIR"
elif [ -n "${SPACEGUARD_BUILD_ROOT:-}" ]; then
    if [ -f "$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/apple/Products/Release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/apple/Products/Release"
    elif [ -f "$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/release"
    elif [ -f "$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/arm64-apple-macosx/release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/$SPACEGUARD_BUILD_ROOT/arm64-apple-macosx/release"
    else
        echo "Error: $APP_NAME executable not found in SPACEGUARD_BUILD_ROOT=$SPACEGUARD_BUILD_ROOT"
        exit 1
    fi
else
    # Determine build directory (universal binary may be in different location)
    if [ -f "$PROJECT_DIR/.build/apple/Products/Release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
    elif [ -f "$PROJECT_DIR/.build/release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/.build/release"
    elif [ -f "$PROJECT_DIR/.build/arm64-apple-macosx/release/$APP_NAME" ]; then
        BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/release"
    else
        echo "Error: $APP_NAME executable not found"
        echo "Please build the project first: swift build --configuration release"
        exit 1
    fi
fi

echo "Creating $APP_NAME.app bundle..."
echo "Using build directory: $BUILD_DIR"
echo "Using app version: $APP_VERSION"

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
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
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
