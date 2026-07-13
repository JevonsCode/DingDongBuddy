#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /path/to/DingDong.app /path/to/DingDong-version-macos.dmg" >&2
  exit 64
fi

app_path="$1"
output_path="$2"

if [ ! -d "$app_path" ]; then
  echo "App bundle does not exist: $app_path" >&2
  exit 66
fi

case "$app_path" in
  *.app) ;;
  *)
    echo "Expected a macOS .app bundle: $app_path" >&2
    exit 65
    ;;
esac

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dingdong-dmg.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT HUP INT TERM

staging_directory="$temporary_directory/DingDong"
/bin/mkdir -p "$staging_directory"
/usr/bin/ditto "$app_path" "$staging_directory/$(/usr/bin/basename "$app_path")"
/bin/ln -s /Applications "$staging_directory/Applications"

/bin/mkdir -p "$(/usr/bin/dirname "$output_path")"
/bin/rm -f "$output_path"
/usr/bin/hdiutil create \
  -volname "DingDong" \
  -fs APFS \
  -format UDZO \
  -imagekey zlib-level=9 \
  -srcfolder "$staging_directory" \
  -ov \
  "$output_path"

/usr/bin/hdiutil verify "$output_path"
