#!/usr/bin/env bash
set -euo pipefail

echo "=== Building OrcaNotes (Release) ==="
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. Compile Swift in Release mode
# Build each architecture separately, then merge. (A single multi-arch
# `swift build` uses the Xcode build system, which rejects WhisperKit's
# duplicate CLI product names.)
swift build -c release --arch arm64
swift build -c release --arch x86_64
UNIVERSAL=".build/universal-release"
rm -rf "$UNIVERSAL" && mkdir -p "$UNIVERSAL"
lipo -create \
  .build/arm64-apple-macosx/release/OrcaNotes \
  .build/x86_64-apple-macosx/release/OrcaNotes \
  -output "$UNIVERSAL/OrcaNotes"

# 2. Setup .app bundle structure
APP_DIR="build/OrcaNotes.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. Copy executable & Info.plist
cp "$UNIVERSAL/OrcaNotes" "$APP_DIR/Contents/MacOS/OrcaNotes"
cp "Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/OrcaNotes"
# SwiftPM resource bundles (WhisperKit deps) must ship inside the app
for b in .build/arm64-apple-macosx/release/*.bundle; do [ -e "$b" ] && cp -R "$b" "$APP_DIR/Contents/Resources/"; done
cp "assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# 4. Ad-hoc code signing (allows running without $99 Apple Developer cert)
echo "=== Signing OrcaNotes.app (ad-hoc) ==="
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ Build complete! App created at: $APP_DIR"
echo ""
echo "To launch OrcaNotes:"
echo "  open $APP_DIR"
echo ""
echo "For external testers downloading this build:"
echo "  xattr -cr $APP_DIR && open $APP_DIR"
