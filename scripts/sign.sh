#!/bin/bash

# Code signing script for SpaceGuard.app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="SpaceGuard"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
IDENTITY="${1:--}"  # Use ad-hoc signing by default, or provide identity as first argument

echo "Signing $APP_BUNDLE..."

# Check if bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run create-app-bundle.sh first."
    exit 1
fi

# Remove any existing signatures
echo "Removing existing signatures..."
codesign --remove-signature "$APP_BUNDLE" 2>/dev/null || true

# Sign the bundle
echo "Signing with identity: $IDENTITY"
codesign --deep --force --verify --verbose --timestamp \
    --options runtime \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

# Verify the signature
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "✓ Successfully signed $APP_BUNDLE"
echo "Signature details:"
codesign --display --verbose=2 "$APP_BUNDLE"