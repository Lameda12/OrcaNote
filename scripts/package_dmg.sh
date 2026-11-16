#!/usr/bin/env bash
set -e

echo "=== Packaging OrcaNotes.dmg ==="
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. Ensure latest app is built
./scripts/build_app.sh

# 2. Setup DMG staging directory
DMG_STAGING="build/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

cp -R "build/OrcaNotes.app" "$DMG_STAGING/OrcaNotes.app"
ln -s /Applications "$DMG_STAGING/Applications"

# 3. Create compressed DMG
DMG_OUTPUT="build/OrcaNotes.dmg"
rm -f "$DMG_OUTPUT"

hdiutil create -volname "OrcaNotes" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_OUTPUT"

rm -rf "$DMG_STAGING"

echo ""
echo "✅ DMG Packaging complete: $DMG_OUTPUT"
echo "Size: $(du -sh "$DMG_OUTPUT" | cut -f1)"
