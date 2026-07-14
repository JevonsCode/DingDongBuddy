#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /path/to/DingDong.app /path/to/DingDong-version-macos.dmg" >&2
  exit 64
fi

app_path="$1"
output_path="$2"
script_directory="$(CDPATH= cd -- "$(/usr/bin/dirname -- "$0")" && pwd)"
repository_root="$(/usr/bin/dirname "$script_directory")"
background_template="$repository_root/Assets/installer/dmg-background.svg"
guide_path="$repository_root/Assets/installer/安装与权限说明.txt"
logo_path="$repository_root/Assets/AgentToolIcon.png"
settings_path="$script_directory/dmg_settings.py"

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

for required_path in \
  "$background_template" \
  "$guide_path" \
  "$logo_path" \
  "$settings_path" \
  "$app_path/Contents/Resources/AppIcon.icns"
do
  if [ ! -e "$required_path" ]; then
    echo "Required installer asset does not exist: $required_path" >&2
    exit 66
  fi
done

dmgbuild_bin="${DMGBUILD_BIN:-}"
if [ -z "$dmgbuild_bin" ]; then
  dmgbuild_bin="$(command -v dmgbuild || true)"
fi
if [ -z "$dmgbuild_bin" ] || [ ! -x "$dmgbuild_bin" ]; then
  echo "dmgbuild is required. Install dmgbuild 1.6.7 or set DMGBUILD_BIN." >&2
  exit 69
fi

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dingdong-dmg.XXXXXX")"
mountpoint="$temporary_directory/mount"
cleanup() {
  /usr/bin/hdiutil detach "$mountpoint" >/dev/null 2>&1 || true
  /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT HUP INT TERM

rendered_svg="$temporary_directory/dmg-background.svg"
rendered_background="$temporary_directory/dmg-background.png"
read_write_image="$temporary_directory/DingDong-read-write.dmg"

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    *DINGDONG_LOGO_DATA*)
      prefix="${line%%DINGDONG_LOGO_DATA*}"
      suffix="${line#*DINGDONG_LOGO_DATA}"
      /usr/bin/printf '%s' "$prefix" >> "$rendered_svg"
      /usr/bin/base64 < "$logo_path" | /usr/bin/tr -d '\n' >> "$rendered_svg"
      /usr/bin/printf '%s\n' "$suffix" >> "$rendered_svg"
      ;;
    *)
      /usr/bin/printf '%s\n' "$line" >> "$rendered_svg"
      ;;
  esac
done < "$background_template"

/usr/bin/sips -s format png "$rendered_svg" \
  --out "$rendered_background" >/dev/null

/bin/mkdir -p "$(/usr/bin/dirname "$output_path")"
/bin/rm -f "$output_path"
app_path="$(CDPATH= cd -- "$(/usr/bin/dirname -- "$app_path")" && pwd)/$(/usr/bin/basename "$app_path")"
output_path="$(CDPATH= cd -- "$(/usr/bin/dirname -- "$output_path")" && pwd)/$(/usr/bin/basename "$output_path")"

"$dmgbuild_bin" \
  -s "$settings_path" \
  -D "app_path=$app_path" \
  -D "background_path=$rendered_background" \
  -D "guide_path=$guide_path" \
  -D "icon_path=$app_path/Contents/Resources/AppIcon.icns" \
  "DingDong" \
  "$read_write_image"

# Set Finder's custom-volume-icon flag without depending on Xcode's SetFile.
# dmgbuild has already copied the canonical AppIcon.icns to .VolumeIcon.icns.
/bin/mkdir -p "$mountpoint"
/usr/bin/hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$mountpoint" \
  "$read_write_image" >/dev/null
/usr/bin/xattr -wx com.apple.FinderInfo \
  0000000000000000040000000000000000000000000000000000000000000000 \
  "$mountpoint"
# Finder's per-file extension-hiding flag invalidates strict bundle signature
# verification when copied out of the DMG. Keep the visible `.app` extension
# and remove the flag defensively before sealing the final image.
/usr/bin/xattr -d com.apple.FinderInfo \
  "$mountpoint/$(/usr/bin/basename "$app_path")" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict \
  "$mountpoint/$(/usr/bin/basename "$app_path")"
/bin/rm -rf "$mountpoint/.fseventsd" "$mountpoint/.Trashes"
/usr/bin/hdiutil detach "$mountpoint" >/dev/null

/usr/bin/hdiutil convert "$read_write_image" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$output_path" >/dev/null

/usr/bin/hdiutil verify "$output_path"
