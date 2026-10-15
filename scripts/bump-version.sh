#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: bump-version.sh <x.y.z>}"

PLIST="MeetingReminder/Info.plist"
PBXPROJ="MeetingReminder.xcodeproj/project.pbxproj"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST"

sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $VERSION;/g" "$PBXPROJ"

echo "Bumped to $VERSION"
