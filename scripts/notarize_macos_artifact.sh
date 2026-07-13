#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/DingDong.app-or.dmg" >&2
  exit 64
fi

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD is required}"

artifact_path="$1"
if [ ! -e "$artifact_path" ]; then
  echo "Artifact does not exist: $artifact_path" >&2
  exit 66
fi

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dingdong-notary.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT HUP INT TERM

submission_path="$artifact_path"
case "$artifact_path" in
  *.app)
    submission_path="$temporary_directory/DingDong.zip"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent \
      "$artifact_path" \
      "$submission_path"
    ;;
  *.dmg) ;;
  *)
    echo "Only .app and .dmg artifacts can be notarized by this script." >&2
    exit 65
    ;;
esac

/usr/bin/xcrun notarytool submit "$submission_path" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
/usr/bin/xcrun stapler staple "$artifact_path"
/usr/bin/xcrun stapler validate "$artifact_path"
