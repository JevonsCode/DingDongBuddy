#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 /path/to/DingDong.app [entitlements.plist]" >&2
  exit 64
fi

app_path="$1"
entitlements_path="${2:-macos/Runner/Release.entitlements}"
local_identity="${DINGDONG_LOCAL_SIGNING_IDENTITY:-DingDong Local Development}"
identity="${CODE_SIGN_IDENTITY:-}"

if [ -z "$identity" ]; then
  if /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/grep -F "\"$local_identity\"" >/dev/null; then
    identity="$local_identity"
  else
    identity="-"
    echo "warning: stable signing identity '$local_identity' is unavailable; using ad-hoc signing" >&2
  fi
fi

if [ ! -d "$app_path" ]; then
  echo "App bundle does not exist: $app_path" >&2
  exit 66
fi

# The MCP build phase runs after Flutter embeds App.framework. Re-sign the
# complete bundle so both post-build artifacts are included in the seal.
if [ "$identity" = "-" ]; then
  /usr/bin/codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "$entitlements_path" \
    "$app_path"
else
  case "$identity" in
    "Developer ID Application:"*)
      /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$identity" \
        --entitlements "$entitlements_path" \
        "$app_path"
      ;;
    *)
      /usr/bin/codesign \
        --force \
        --deep \
        --timestamp=none \
        --sign "$identity" \
        --entitlements "$entitlements_path" \
        "$app_path"
      ;;
  esac
fi

/usr/bin/codesign --verify --deep --strict "$app_path"
