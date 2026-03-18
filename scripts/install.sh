#!/bin/bash

# SpaceGuard Installation Script
# Installs SpaceGuard to /Applications

set -e

echo "SpaceGuard Installer"
echo "===================="

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: SpaceGuard requires macOS"
    exit 1
fi

# Check Swift
if ! command -v swift &> /dev/null; then
    echo "Error: Swift not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Build the project (Universal Binary)
echo "Building SpaceGuard (Universal Binary for arm64/x86_64)..."
swift build --configuration release --arch arm64 --arch x86_64

# Create .app bundle
echo "Creating application bundle..."
./scripts/create-app-bundle.sh

# Sign the application bundle (ad-hoc signing)
echo "Signing application bundle..."
./scripts/sign.sh

# Install to Applications
APP_BUNDLE="SpaceGuard.app"
APPLICATIONS_DIR="/Applications"

echo ""
echo "Installation options:"
echo "1. Install to $APPLICATIONS_DIR (requires sudo)"
echo "2. Create local copy in current directory"
echo "3. Exit without installing"
echo ""
read -p "Choose option [1-3]: " choice

case $choice in
    1)
        echo "Installing to $APPLICATIONS_DIR..."
        sudo rm -rf "$APPLICATIONS_DIR/$APP_BUNDLE"
        sudo cp -R "$APP_BUNDLE" "$APPLICATIONS_DIR/"
        sudo chown -R "$USER:staff" "$APPLICATIONS_DIR/$APP_BUNDLE"
        echo "✓ Installed to $APPLICATIONS_DIR/$APP_BUNDLE"
        echo ""
        echo "To run SpaceGuard:"
        echo "  • Open $APPLICATIONS_DIR/$APP_BUNDLE"
        echo "  • Or double-click in Finder"
        echo ""
        echo "SpaceGuard will appear in your menu bar (top-right)."
        ;;
    2)
        echo "Application bundle created: $(pwd)/$APP_BUNDLE"
        echo ""
        echo "To run SpaceGuard:"
        echo "  • Double-click SpaceGuard.app in Finder"
        echo "  • Or run: open SpaceGuard.app"
        ;;
    3)
        echo "Installation cancelled."
        echo "Application bundle created at: $(pwd)/$APP_BUNDLE"
        ;;
    *)
        echo "Invalid choice. Installation cancelled."
        ;;
esac

echo ""
echo "Uninstall instructions:"
echo "  • Remove $APPLICATIONS_DIR/$APP_BUNDLE"
echo "  • Or run: sudo rm -rf /Applications/SpaceGuard.app"
echo ""
echo "For more information, see README.md"