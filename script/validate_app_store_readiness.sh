#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Validate static App Store metadata =="
plutil -lint Config/Info.plist
plutil -lint Config/SpaceLens.entitlements
plutil -lint Config/ExportOptions-AppStore.plist
plutil -lint Resources/PrivacyInfo.xcprivacy

test -f Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
test -f Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

echo "== Validate entitlements =="
plutil -p Config/SpaceLens.entitlements | grep -q '"com.apple.security.app-sandbox" => true'
plutil -p Config/SpaceLens.entitlements | grep -q '"com.apple.security.files.user-selected.read-write" => true'

echo "== Validate Info.plist version keys =="
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Config/Info.plist >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Config/Info.plist >/dev/null
/usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" Config/Info.plist | grep -q public.app-category.utilities

echo "== Generate Xcode project =="
./script/generate_xcode_project.sh

echo "== SwiftPM tests =="
swift test

echo "== Xcode app build without signing =="
xcodebuild \
  -project SpaceLens.xcodeproj \
  -scheme SpaceLens \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "App Store readiness metadata validation passed."
