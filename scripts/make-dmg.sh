#!/bin/bash

# Create DMG distribution for SpaceGuard

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="SpaceGuard"

# Get version from command line argument or environment variable
if [ -n "$1" ]; then
    VERSION="$1"
elif [ -n "${VERSION}" ]; then
    # Use environment variable if set
    VERSION="${VERSION}"
else
    VERSION="1.0.0"
fi

# Remove 'v' prefix if present (e.g., v1.0.0 -> 1.0.0)
VERSION="${VERSION#v}"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
TEMP_DIR="/tmp/${APP_NAME}-dmg"

echo "Creating DMG distribution..."
echo "App: $APP_NAME"
echo "Version: $VERSION"
echo "DMG: $DMG_NAME"

# Clean up
rm -rf "$TEMP_DIR"
rm -f "$PROJECT_DIR/$DMG_NAME"

# Build if needed (Universal Binary)
if [ ! -f "$PROJECT_DIR/.build/release/$APP_NAME" ]; then
    echo "Building release version (Universal Binary for arm64/x86_64)..."
    swift build --configuration release --arch arm64 --arch x86_64
fi

# Create .app bundle if needed
if [ ! -d "$PROJECT_DIR/$APP_NAME.app" ]; then
    echo "Creating application bundle..."
    ./scripts/create-app-bundle.sh
fi

# Sign the application bundle (ad-hoc signing)
echo "Signing application bundle..."
./scripts/sign.sh

# Create temporary directory structure
echo "Creating DMG layout..."
mkdir -p "$TEMP_DIR"
cp -R "$PROJECT_DIR/$APP_NAME.app" "$TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Create README file
cat > "$TEMP_DIR/README.txt" << EOF
SpaceGuard ${VERSION}
====================

A macOS status bar application for disk space management with risk-based file cleanup.

Installation:
1. Drag SpaceGuard.app to the Applications folder
2. Open SpaceGuard.app from Applications
3. The app will appear in your menu bar (top-right)

Features:
- Disk usage monitoring
- Risk-based file classification (Low/Medium/High)
- Safe cleanup with progress tracking
- Status bar interface
- Native macOS integration

System Requirements:
- macOS 12.0 or later

Uninstall:
- Drag SpaceGuard.app to Trash
- Or run: rm -rf /Applications/SpaceGuard.app

For more information, visit:
https://github.com/NoTalkTech/SpaceGuard

EOF

# Create DMG
echo "Creating DMG file..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+J \
    "$PROJECT_DIR/$DMG_NAME"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "✓ DMG created: $PROJECT_DIR/$DMG_NAME"
echo "Size: $(du -sh "$PROJECT_DIR/$DMG_NAME" | cut -f1)"
echo ""
echo "To distribute:"
echo "  • Upload $DMG_NAME to GitHub Releases"
echo "  • Users can download and open the DMG"
echo "  • Drag SpaceGuard.app to Applications"