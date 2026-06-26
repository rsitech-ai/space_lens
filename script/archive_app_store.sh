#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SPACE_LENS_DEVELOPMENT_TEAM:-}" ]]; then
  echo "Set SPACE_LENS_DEVELOPMENT_TEAM to your Apple Developer Team ID." >&2
  echo "Example: SPACE_LENS_DEVELOPMENT_TEAM=ABCDE12345 ./script/archive_app_store.sh" >&2
  exit 2
fi

if ! security find-identity -p codesigning -v | grep -Eq '"(Apple Distribution|3rd Party Mac Developer Application):'; then
  echo "No App Store distribution signing identity was found in the keychain." >&2
  echo "Install or create an Apple Distribution certificate in Xcode > Settings > Accounts > Manage Certificates." >&2
  exit 2
fi

ARCHIVE_DIR="$ROOT_DIR/build/AppStore"
ARCHIVE_PATH="$ARCHIVE_DIR/SpaceLens.xcarchive"
EXPORT_PATH="$ARCHIVE_DIR/export"

./script/generate_xcode_project.sh

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

echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"
echo
echo "Upload the exported package with Xcode Organizer, Transporter, or App Store Connect API tooling."
