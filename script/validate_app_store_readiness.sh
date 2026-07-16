#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DERIVED_DATA_PATH="${SPACE_LENS_VALIDATION_DERIVED_DATA:-${TMPDIR:-/tmp}/spacelens-app-store-validation}"

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
plutil -p Config/SpaceLens.entitlements | grep -q '"com.apple.security.files.bookmarks.app-scope" => true'

echo "== Validate Info.plist version keys =="
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Config/Info.plist >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Config/Info.plist >/dev/null
/usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" Config/Info.plist | grep -q public.app-category.utilities

echo "== Generate Xcode project =="
./script/generate_xcode_project.sh
git diff --exit-code -- SpaceLens.xcodeproj

echo "== SwiftPM tests =="
swift test

echo "== Xcode app build without signing =="
xcodebuild \
  -project SpaceLens.xcodeproj \
  -scheme SpaceLens \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT_INFO_PLIST="$DERIVED_DATA_PATH/Build/Products/Debug/SpaceLens.app/Contents/Info.plist"
test -f "$BUILT_INFO_PLIST"
EXPECTED_VERSION="$(awk -F '"' '/MARKETING_VERSION:/ { print $2; exit }' project.yml)"
EXPECTED_BUILD="$(awk -F '"' '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' project.yml)"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_INFO_PLIST")" = "$EXPECTED_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT_INFO_PLIST")" = "$EXPECTED_BUILD"
test -f "$DERIVED_DATA_PATH/Build/Products/Debug/SpaceLens.app/Contents/Resources/PrivacyInfo.xcprivacy"

echo "Validated bundle version $EXPECTED_VERSION ($EXPECTED_BUILD)."

echo "App Store readiness metadata validation passed."
