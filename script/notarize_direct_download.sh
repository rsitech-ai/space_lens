#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpaceLens"

usage() {
  cat <<'EOF'
Finalize an existing Developer ID-signed SpaceLens direct-download artifact.

Usage:
  SPACE_LENS_NOTARY_PROFILE='SpaceLens-notary' \
  SPACE_LENS_RELEASE_INPUT_DIR='/absolute/path/to/pre-notarization-artifacts' \
  SPACE_LENS_NOTARIZED_OUTPUT_DIR='/absolute/path/to/final-artifacts' \
    ./script/notarize_direct_download.sh
  ./script/notarize_direct_download.sh --help

Required environment:
  SPACE_LENS_NOTARY_PROFILE          Keychain profile created with notarytool.
  SPACE_LENS_RELEASE_INPUT_DIR       Pre-notarization output from
                                     build_direct_download.sh.
  SPACE_LENS_NOTARIZED_OUTPUT_DIR    New or empty absolute final artifact
                                     directory, separate from the input.

The script submits the signed input ZIP, waits for Apple to accept it, staples
and validates a copy of the app, then creates a new ZIP from that stapled copy.
It does not modify the pre-notarization input. Submission uploads the ZIP to
Apple and therefore requires explicit release authority.
EOF
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

NOTARY_PROFILE="${SPACE_LENS_NOTARY_PROFILE:-}"
INPUT_DIR="${SPACE_LENS_RELEASE_INPUT_DIR:-}"
OUTPUT_DIR="${SPACE_LENS_NOTARIZED_OUTPUT_DIR:-}"

if [[ -z "$NOTARY_PROFILE" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "Set SPACE_LENS_NOTARY_PROFILE, SPACE_LENS_RELEASE_INPUT_DIR, and SPACE_LENS_NOTARIZED_OUTPUT_DIR." >&2
  exit 1
fi

validate_absolute_path() {
  local candidate="$1"
  local label="$2"

  if [[ "$candidate" != /* ]]; then
    echo "$label must be absolute: $candidate" >&2
    exit 1
  fi
  if [[ "$candidate" == "/" || "$candidate" == "$HOME" || "$candidate" == "$ROOT_DIR" ]]; then
    echo "Refusing unsafe $label: $candidate" >&2
    exit 1
  fi
  if [[ -L "$candidate" ]]; then
    echo "Refusing symbolic-link $label: $candidate" >&2
    exit 1
  fi
}

validate_absolute_path "$INPUT_DIR" "input directory"
validate_absolute_path "$OUTPUT_DIR" "output directory"

validate_release_path_scope() {
  local release_path="$1"
  local relative_release_path

  if [[ "$release_path" != "$ROOT_DIR"/* ]]; then
    return
  fi

  relative_release_path="${release_path#"$ROOT_DIR"/}"
  if ! git -C "$ROOT_DIR" check-ignore -q --no-index -- "$relative_release_path" &&
     ! git -C "$ROOT_DIR" check-ignore -q --no-index -- "${relative_release_path}/"; then
    echo "Final output inside the source tree must be ignored by Git: $release_path" >&2
    exit 1
  fi
}

validate_release_path_scope "$OUTPUT_DIR"

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory does not exist: $INPUT_DIR" >&2
  exit 1
fi
if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
  echo "Output path exists and is not a directory: $OUTPUT_DIR" >&2
  exit 1
fi
if [[ -d "$OUTPUT_DIR" ]] && find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  echo "Output directory must be new or empty: $OUTPUT_DIR" >&2
  exit 1
fi

INPUT_DIR="$(/bin/realpath "$INPUT_DIR")"
OUTPUT_PARENT="$(dirname "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_PARENT"
OUTPUT_PARENT="$(/bin/realpath "$OUTPUT_PARENT")"
OUTPUT_DIR="$OUTPUT_PARENT/$(basename "$OUTPUT_DIR")"
validate_release_path_scope "$OUTPUT_DIR"

if [[ "$INPUT_DIR" == "$OUTPUT_DIR" ||
      "$INPUT_DIR" == "$OUTPUT_DIR"/* ||
      "$OUTPUT_DIR" == "$INPUT_DIR"/* ]]; then
  echo "Input and output directories must not be equal or nested." >&2
  exit 1
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)" ]]; then
  echo "Refusing to finalize from a dirty source tree." >&2
  exit 1
fi

BUILD_INFO="$INPUT_DIR/BUILD_INFO.txt"
CHECKSUMS="$INPUT_DIR/SHA256SUMS.txt"
INPUT_APP="$INPUT_DIR/$APP_NAME.app"

for required_path in "$BUILD_INFO" "$CHECKSUMS" "$INPUT_APP"; do
  if [[ ! -e "$required_path" ]]; then
    echo "Missing required pre-notarization input: $required_path" >&2
    exit 1
  fi
done

SOURCE_SHA="$(awk -F ': ' '/^Source commit:/ { print $2; exit }' "$BUILD_INFO")"
SOURCE_TREE="$(awk -F ': ' '/^Source tree:/ { print $2; exit }' "$BUILD_INFO")"
VERSION="$(awk -F ': ' '/^Version:/ { print $2; exit }' "$BUILD_INFO")"
NOTARIZATION_STATE="$(awk -F ': ' '/^Notarization:/ { print $2; exit }' "$BUILD_INFO")"

if [[ -z "$SOURCE_SHA" || -z "$SOURCE_TREE" || -z "$VERSION" ]]; then
  echo "BUILD_INFO.txt is missing source or version provenance." >&2
  exit 1
fi
if [[ "$NOTARIZATION_STATE" != "not submitted" ]]; then
  echo "Expected a pre-notarization artifact; found: $NOTARIZATION_STATE" >&2
  exit 1
fi

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
    echo "Input artifact provenance no longer matches the current clean source revision." >&2
    exit 1
  fi
}

verify_source_revision

ZIP_NAME="$APP_NAME-$VERSION-macOS-universal.zip"
INPUT_ZIP="$INPUT_DIR/$ZIP_NAME"
if [[ ! -f "$INPUT_ZIP" ]]; then
  echo "Missing expected pre-notarization ZIP: $INPUT_ZIP" >&2
  exit 1
fi

(
  cd "$INPUT_DIR"
  shasum -a 256 -c "$(basename "$CHECKSUMS")"
)

codesign --verify --deep --strict --verbose=2 "$INPUT_APP"
SIGNING_DETAILS="$(codesign -d --verbose=4 "$INPUT_APP" 2>&1)"
grep -Fq "Authority=Developer ID Application:" <<<"$SIGNING_DETAILS"
grep -Eq 'flags=.*runtime' <<<"$SIGNING_DETAILS"
grep -Fq "Timestamp=" <<<"$SIGNING_DETAILS"

STAGING_DIR="$(mktemp -d "$OUTPUT_PARENT/.spacelens-notarized.XXXXXX")"
cleanup() {
  if [[ -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

NOTARY_RESULT="$STAGING_DIR/NOTARIZATION_INFO.json"
xcrun notarytool submit "$INPUT_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --output-format json >"$NOTARY_RESULT"

NOTARY_STATUS="$(plutil -extract status raw -o - "$NOTARY_RESULT")"
test "$NOTARY_STATUS" = "Accepted"

STAGED_APP="$STAGING_DIR/$APP_NAME.app"
STAGED_ZIP="$STAGING_DIR/$ZIP_NAME"
/usr/bin/ditto "$INPUT_APP" "$STAGED_APP"
xcrun stapler staple "$STAGED_APP"
xcrun stapler validate "$STAGED_APP"
spctl -a -vv -t execute "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$STAGED_ZIP"

awk '
  /^Notarization:/ { print "Notarization: accepted and stapled"; next }
  { print }
' "$BUILD_INFO" >"$STAGING_DIR/BUILD_INFO.txt"

(
  cd "$STAGING_DIR"
  shasum -a 256 "$ZIP_NAME" >SHA256SUMS.txt
  shasum -a 256 -c SHA256SUMS.txt
)

verify_source_revision

if [[ -d "$OUTPUT_DIR" ]]; then
  rmdir "$OUTPUT_DIR"
fi
mv "$STAGING_DIR" "$OUTPUT_DIR"
trap - EXIT

printf 'Created notarized app: %s\n' "$OUTPUT_DIR/$APP_NAME.app"
printf 'Created notarized ZIP: %s\n' "$OUTPUT_DIR/$ZIP_NAME"
printf 'Created receipt: %s\n' "$OUTPUT_DIR/NOTARIZATION_INFO.json"
