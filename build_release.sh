#!/bin/bash
# Build and package MeetingReminder for team distribution
# Usage: ./build_release.sh [version]
# Requires: Xcode installed

set -e

VERSION="${1:-1.1.0}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build_release"
ARCHIVE_PATH="$BUILD_DIR/MeetingReminder.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
ZIP_NAME="MeetingReminder-$VERSION.zip"

echo "→ Building MeetingReminder v$VERSION"

# Ensure Xcode is available
if ! /usr/bin/xcodebuild -version &>/dev/null; then
    echo "✗ Xcode not found. Install from the App Store."
    exit 1
fi

# Clean build dir
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive
echo "→ Archiving..."
/usr/bin/xcodebuild \
    -project "$PROJECT_DIR/MeetingReminder.xcodeproj" \
    -scheme MeetingReminder \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    MARKETING_VERSION="$VERSION" \
    2>&1 | grep -E "^(Build|error:|warning:|✓|→|Archive)" || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "✗ Archive failed — run without grep filter for full output"
    exit 1
fi

# Export (without signing for direct distribution)
echo "→ Exporting app..."
cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

/usr/bin/xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    2>&1 | grep -E "^(error:|Export)" || true

APP_PATH="$EXPORT_PATH/MeetingReminder.app"
if [ ! -d "$APP_PATH" ]; then
    echo "✗ Export failed"
    exit 1
fi

# Update version in bundle
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"

# Package as ZIP (preserves code signature if signed)
echo "→ Creating $ZIP_NAME..."
cd "$EXPORT_PATH"
zip -r --symlinks "$PROJECT_DIR/$ZIP_NAME" "MeetingReminder.app"

echo ""
echo "✓ Done: $PROJECT_DIR/$ZIP_NAME"
echo ""
echo "NOTE: This build is unsigned. Recipients must right-click → Open on first launch."
echo "For signed distribution, set up a Developer ID certificate and re-run."
