#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SPACE_LENS_DEVELOPMENT_TEAM:-}" ]]; then
  echo "Set SPACE_LENS_DEVELOPMENT_TEAM to your Apple Developer Team ID." >&2
  echo "Example: SPACE_LENS_DEVELOPMENT_TEAM=ABCDE12345 ./script/archive_app_store.sh" >&2
  exit 2
fi

if ! security find-identity -p codesigning -v | grep -Eq "\"Apple Distribution: .+ \\(${SPACE_LENS_DEVELOPMENT_TEAM}\\)\""; then
  echo "No Apple Distribution identity for team $SPACE_LENS_DEVELOPMENT_TEAM was found in the keychain." >&2
  echo "Install or create an Apple Distribution certificate in Xcode > Settings > Accounts > Manage Certificates." >&2
  exit 2
fi

if ! security find-identity -p basic -v | grep -Eq "\"3rd Party Mac Developer Installer: .+ \\(${SPACE_LENS_DEVELOPMENT_TEAM}\\)\""; then
  echo "No Mac App Store installer identity for team $SPACE_LENS_DEVELOPMENT_TEAM was found in the keychain." >&2
  exit 2
fi

ARCHIVE_DIR="${SPACE_LENS_ARCHIVE_ROOT:-$ROOT_DIR/build/AppStore}"
ARCHIVE_PATH="$ARCHIVE_DIR/SpaceLens.xcarchive"
EXPORT_PATH="$ARCHIVE_DIR/export"
LOCK_DIR="$ARCHIVE_DIR.lock"
EXPANSION_ROOT=""

mkdir -p "$(dirname "$ARCHIVE_DIR")"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another SpaceLens archive operation is using $ARCHIVE_DIR." >&2
  exit 2
fi
cleanup() {
  if [[ -n "$EXPANSION_ROOT" ]]; then
    rm -rf "$EXPANSION_ROOT"
  fi
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

./script/generate_xcode_project.sh

if [[ "${SPACE_LENS_ALLOW_DIRTY_ARCHIVE:-0}" != "1" ]] && [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo "Refusing to archive a dirty source tree. Commit the release source or set SPACE_LENS_ALLOW_DIRTY_ARCHIVE=1 for a non-final diagnostic build." >&2
  exit 2
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$ARCHIVE_DIR"

xcodebuild \
  -project SpaceLens.xcodeproj \
  -scheme SpaceLens \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$SPACE_LENS_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist Config/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates

ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/SpaceLens.app"
EXPECTED_VERSION="$(awk -F '"' '/MARKETING_VERSION:/ { print $2; exit }' project.yml)"
EXPECTED_BUILD="$(awk -F '"' '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' project.yml)"
EXPECTED_BUNDLE_ID="$(awk -F ': ' '/PRODUCT_BUNDLE_IDENTIFIER:/ { print $2; exit }' project.yml)"
EXPECTED_MINIMUM_OS="$(awk -F '"' '/MACOSX_DEPLOYMENT_TARGET:/ { print $2; exit }' project.yml)"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ARCHIVED_APP/Contents/Info.plist")" = "$EXPECTED_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ARCHIVED_APP/Contents/Info.plist")" = "$EXPECTED_BUILD"
codesign --verify --deep --strict --verbose=2 "$ARCHIVED_APP"

shopt -s nullglob
EXPORTED_PACKAGES=("$EXPORT_PATH"/*.pkg)
shopt -u nullglob
if [[ ${#EXPORTED_PACKAGES[@]} -ne 1 ]]; then
  echo "Expected exactly one exported .pkg; found ${#EXPORTED_PACKAGES[@]}." >&2
  exit 2
fi
EXPORTED_PACKAGE="${EXPORTED_PACKAGES[0]}"

PACKAGE_SIGNATURE="$(pkgutil --check-signature "$EXPORTED_PACKAGE")"
grep -Fq "3rd Party Mac Developer Installer:" <<<"$PACKAGE_SIGNATURE"
grep -Fq "($SPACE_LENS_DEVELOPMENT_TEAM)" <<<"$PACKAGE_SIGNATURE"

EXPANSION_ROOT="$(mktemp -d "$ARCHIVE_DIR/verification.XXXXXX")"
pkgutil --expand-full "$EXPORTED_PACKAGE" "$EXPANSION_ROOT/package"
EXPORTED_APP_COUNT="$(find "$EXPANSION_ROOT/package" -type d -name 'SpaceLens.app' | wc -l | tr -d ' ')"
if [[ "$EXPORTED_APP_COUNT" != "1" ]]; then
  echo "Expected exactly one SpaceLens.app in the exported package; found $EXPORTED_APP_COUNT." >&2
  exit 2
fi
EXPORTED_APP="$(find "$EXPANSION_ROOT/package" -type d -name 'SpaceLens.app' -print -quit)"
EXPORTED_BINARY="$EXPORTED_APP/Contents/MacOS/SpaceLens"

codesign --verify --deep --strict --verbose=2 "$EXPORTED_APP"
SIGNING_DETAILS="$(codesign -dv --verbose=4 "$EXPORTED_APP" 2>&1)"
grep -Eq "Authority=Apple Distribution: .+ \($SPACE_LENS_DEVELOPMENT_TEAM\)" <<<"$SIGNING_DETAILS"
grep -Fq "TeamIdentifier=$SPACE_LENS_DEVELOPMENT_TEAM" <<<"$SIGNING_DETAILS"
grep -Eq '^CodeDirectory .*flags=.*\(runtime\)' <<<"$SIGNING_DETAILS"

ENTITLEMENTS_PLIST="$EXPANSION_ROOT/entitlements.plist"
codesign -d --entitlements :- "$EXPORTED_APP" > "$ENTITLEMENTS_PLIST" 2>/dev/null
for entitlement in \
  com.apple.security.app-sandbox \
  com.apple.security.files.user-selected.read-write \
  com.apple.security.files.bookmarks.app-scope; do
  test "$(/usr/libexec/PlistBuddy -c "Print :$entitlement" "$ENTITLEMENTS_PLIST")" = "true"
done
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$ENTITLEMENTS_PLIST" 2>/dev/null || true)" != "true"

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXPORTED_APP/Contents/Info.plist")" = "$EXPECTED_BUNDLE_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXPORTED_APP/Contents/Info.plist")" = "$EXPECTED_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXPORTED_APP/Contents/Info.plist")" = "$EXPECTED_BUILD"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$EXPORTED_APP/Contents/Info.plist")" = "$EXPECTED_MINIMUM_OS"

EXPORTED_PRIVACY="$EXPORTED_APP/Contents/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$EXPORTED_PRIVACY"
cmp Resources/PrivacyInfo.xcprivacy "$EXPORTED_PRIVACY"
QUARANTINED_PATH="$(find "$EXPORTED_APP" -exec sh -c 'xattr -p com.apple.quarantine "$1" >/dev/null 2>&1' _ {} \; -print -quit)"
if [[ -n "$QUARANTINED_PATH" ]]; then
  echo "Exported app contains a quarantine attribute." >&2
  exit 2
fi

ARCHS="$(lipo -archs "$EXPORTED_BINARY")"
grep -qw arm64 <<<"$ARCHS"
grep -qw x86_64 <<<"$ARCHS"
DSYM_UUIDS="$(dwarfdump --uuid "$ARCHIVE_PATH/dSYMs/SpaceLens.app.dSYM" | awk '{ print $2 }' | sort)"
BINARY_UUIDS="$(dwarfdump --uuid "$EXPORTED_BINARY" | awk '{ print $2 }' | sort)"
test -n "$DSYM_UUIDS"
test -n "$BINARY_UUIDS"
test "$DSYM_UUIDS" = "$BINARY_UUIDS"

PROFILE_PLIST="$EXPANSION_ROOT/profile.plist"
security cms -D -i "$EXPORTED_APP/Contents/embedded.provisionprofile" > "$PROFILE_PLIST"
test "$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")" = "$SPACE_LENS_DEVELOPMENT_TEAM"
test "$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$PROFILE_PLIST")" = "$SPACE_LENS_DEVELOPMENT_TEAM.$EXPECTED_BUNDLE_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :Platform:0' "$PROFILE_PLIST")" = "OSX"
PROFILE_EXPIRATION="$(plutil -extract ExpirationDate raw -o - "$PROFILE_PLIST")"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ "$PROFILE_EXPIRATION" > "$NOW_UTC" ]]

echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"
echo "Source: $(git rev-parse HEAD)"
echo "Version: $EXPECTED_VERSION ($EXPECTED_BUILD)"
shasum -a 256 "$EXPORTED_PACKAGE"
echo
echo "Upload the exported package with Xcode Organizer, Transporter, or App Store Connect API tooling."
