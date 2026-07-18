#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/SpaceLens.xcodeproj"
PROJECT_SPEC="$ROOT_DIR/project.yml"
SCHEME="SpaceLens"
APP_NAME="SpaceLens"

VERSION="$(awk -F '"' '/MARKETING_VERSION:/ { print $2; exit }' "$PROJECT_SPEC")"
BUILD_NUMBER="$(awk -F '"' '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$PROJECT_SPEC")"
MINIMUM_MACOS="$(awk -F '"' '/MACOSX_DEPLOYMENT_TARGET:/ { print $2; exit }' "$PROJECT_SPEC")"
BUNDLE_ID="$(awk -F ': ' '/PRODUCT_BUNDLE_IDENTIFIER:/ { print $2; exit }' "$PROJECT_SPEC")"

usage() {
  cat <<'EOF'
Build a Developer ID-signed universal SpaceLens download.

Usage:
  SPACE_LENS_DEVELOPER_ID='Developer ID Application: Name (TEAMID)' \
    ./script/build_direct_download.sh
  ./script/build_direct_download.sh --print-config
  ./script/build_direct_download.sh --help

Optional environment:
  SPACE_LENS_RELEASE_OUTPUT_DIR   New or empty absolute artifact directory.
  SPACE_LENS_RELEASE_DERIVED_DATA New or empty absolute Xcode DerivedData directory.

This script signs with Developer ID and the hardened runtime. It does not submit
the artifact to Apple's notarization service; notarization is a separate,
approval-bound release step.
EOF
}

print_config() {
  printf 'bundle_id=%s\n' "$BUNDLE_ID"
  printf 'version=%s\n' "$VERSION"
  printf 'build=%s\n' "$BUILD_NUMBER"
  printf 'minimum_macos=%s\n' "$MINIMUM_MACOS"
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --print-config)
    print_config
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

DEVELOPER_ID="${SPACE_LENS_DEVELOPER_ID:-}"
OUTPUT_DIR="${SPACE_LENS_RELEASE_OUTPUT_DIR:-$ROOT_DIR/dist/final}"
DERIVED_DATA="${SPACE_LENS_RELEASE_DERIVED_DATA:-$ROOT_DIR/DerivedData/DirectDownload}"

if [[ -z "$DEVELOPER_ID" ]]; then
  echo "Set SPACE_LENS_DEVELOPER_ID to the exact Developer ID Application identity." >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$DEVELOPER_ID\""; then
  echo "Developer ID identity is not available: $DEVELOPER_ID" >&2
  exit 1
fi

for release_path in "$OUTPUT_DIR" "$DERIVED_DATA"; do
  if [[ "$release_path" != /* ]]; then
    echo "Release paths must be absolute: $release_path" >&2
    exit 1
  fi
  if [[ "$release_path" == "/" || "$release_path" == "$HOME" || "$release_path" == "$ROOT_DIR" ]]; then
    echo "Refusing unsafe release path: $release_path" >&2
    exit 1
  fi
  if [[ -L "$release_path" ]]; then
    echo "Refusing a symbolic-link release path: $release_path" >&2
    exit 1
  fi
  if [[ -d "$release_path" ]] && find "$release_path" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "Release path must be new or empty: $release_path" >&2
    exit 1
  fi
done

validate_release_path_scope() {
  local release_path="$1"
  local relative_release_path

  if [[ "$release_path" != "$ROOT_DIR"/* ]]; then
    return
  fi

  relative_release_path="${release_path#"$ROOT_DIR"/}"
  if ! git -C "$ROOT_DIR" check-ignore -q --no-index -- "$relative_release_path" &&
     ! git -C "$ROOT_DIR" check-ignore -q --no-index -- "${relative_release_path}/"; then
    echo "Release paths inside the source tree must be ignored by Git: $release_path" >&2
    exit 1
  fi
}

# Validate the lexical paths before creating them, then validate their resolved
# locations as well so a symlinked parent cannot bypass the source-tree guard.
validate_release_path_scope "$OUTPUT_DIR"
validate_release_path_scope "$DERIVED_DATA"
mkdir -p "$OUTPUT_DIR" "$DERIVED_DATA"
OUTPUT_DIR="$(/bin/realpath "$OUTPUT_DIR")"
DERIVED_DATA="$(/bin/realpath "$DERIVED_DATA")"

RESOLVED_HOME="$(/bin/realpath "$HOME")"
for release_path in "$OUTPUT_DIR" "$DERIVED_DATA"; do
  if [[ "$release_path" == "/" ||
        "$release_path" == "$RESOLVED_HOME" ||
        "$release_path" == "$ROOT_DIR" ]]; then
    echo "Refusing unsafe resolved release path: $release_path" >&2
    exit 1
  fi
done

if [[ "$OUTPUT_DIR" == "$DERIVED_DATA" ||
      "$OUTPUT_DIR" == "$DERIVED_DATA"/* ||
      "$DERIVED_DATA" == "$OUTPUT_DIR"/* ]]; then
  echo "Release output and DerivedData paths must not overlap." >&2
  exit 1
fi

validate_release_path_scope "$OUTPUT_DIR"
validate_release_path_scope "$DERIVED_DATA"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)" ]]; then
  echo "Refusing to package a dirty source tree. Commit the exact release source first." >&2
  exit 1
fi

SOURCE_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
SOURCE_TREE="$(git -C "$ROOT_DIR" rev-parse HEAD^{tree})"

verify_source_revision() {
  local current_source_sha
  local current_source_tree
  local current_source_status

  current_source_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  current_source_tree="$(git -C "$ROOT_DIR" rev-parse HEAD^{tree})"
  current_source_status="$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)"

  if [[ "$current_source_sha" != "$SOURCE_SHA" ||
        "$current_source_tree" != "$SOURCE_TREE" ||
        -n "$current_source_status" ]]; then
    echo "Source changed during packaging; refusing to publish mismatched provenance." >&2
    exit 1
  fi
}

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
RELEASE_APP="$OUTPUT_DIR/$APP_NAME.app"
ZIP_NAME="$APP_NAME-$VERSION-macOS-universal.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
BUILD_INFO="$OUTPUT_DIR/BUILD_INFO.txt"
CHECKSUMS="$OUTPUT_DIR/SHA256SUMS.txt"

test -d "$BUILT_APP"
/usr/bin/ditto "$BUILT_APP" "$RELEASE_APP"

codesign \
  --force \
  --options runtime \
  --timestamp \
  --entitlements "$ROOT_DIR/Config/SpaceLens.entitlements" \
  --sign "$DEVELOPER_ID" \
  "$RELEASE_APP"

codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$RELEASE_APP/Contents/Info.plist")" = "$BUNDLE_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RELEASE_APP/Contents/Info.plist")" = "$VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$RELEASE_APP/Contents/Info.plist")" = "$BUILD_NUMBER"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$RELEASE_APP/Contents/Info.plist")" = "$MINIMUM_MACOS"
test -f "$RELEASE_APP/Contents/Resources/PrivacyInfo.xcprivacy"
cmp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$RELEASE_APP/Contents/Resources/PrivacyInfo.xcprivacy"
lipo -archs "$RELEASE_APP/Contents/MacOS/$APP_NAME" | grep -q arm64
lipo -archs "$RELEASE_APP/Contents/MacOS/$APP_NAME" | grep -q x86_64

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$RELEASE_APP" "$ZIP_PATH"

ARCHITECTURES="$(lipo -archs "$RELEASE_APP/Contents/MacOS/$APP_NAME")"

cat >"$BUILD_INFO" <<EOF
SpaceLens direct-download build
Source commit: $SOURCE_SHA
Source tree: $SOURCE_TREE
Bundle identifier: $BUNDLE_ID
Version: $VERSION
Build: $BUILD_NUMBER
Minimum macOS: $MINIMUM_MACOS
Architectures: $ARCHITECTURES
Signing identity: $DEVELOPER_ID
Hardened runtime: enabled
Notarization: not submitted
EOF

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ZIP_NAME" >"$(basename "$CHECKSUMS")"
)

verify_source_revision

printf 'Created %s\n' "$RELEASE_APP"
printf 'Created %s\n' "$ZIP_PATH"
printf 'Created %s\n' "$CHECKSUMS"
printf 'Created %s\n' "$BUILD_INFO"
