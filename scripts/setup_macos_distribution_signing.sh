#!/bin/sh
set -eu

: "${MACOS_CERTIFICATE_BASE64:?MACOS_CERTIFICATE_BASE64 is required}"
: "${MACOS_CERTIFICATE_PASSWORD:?MACOS_CERTIFICATE_PASSWORD is required}"
: "${MACOS_KEYCHAIN_PASSWORD:?MACOS_KEYCHAIN_PASSWORD is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"

temporary_directory="$(/usr/bin/mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/dingdong-certificate.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT HUP INT TERM

certificate_path="$temporary_directory/distribution.p12"
keychain_path="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/dingdong-signing.keychain-db"

/usr/bin/printf '%s' "$MACOS_CERTIFICATE_BASE64" \
  | /usr/bin/base64 -D > "$certificate_path"
/usr/bin/security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$keychain_path"
/usr/bin/security set-keychain-settings -lut 21600 "$keychain_path"
/usr/bin/security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$keychain_path"
/usr/bin/security import "$certificate_path" \
  -P "$MACOS_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$keychain_path"
/usr/bin/security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$MACOS_KEYCHAIN_PASSWORD" \
  "$keychain_path"
/usr/bin/security list-keychain -d user -s "$keychain_path"

identity="$(
  /usr/bin/security find-identity -v -p codesigning "$keychain_path" \
    | /usr/bin/sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | /usr/bin/head -n 1
)"
if [ -z "$identity" ]; then
  echo "The certificate does not contain a Developer ID Application identity." >&2
  exit 65
fi

{
  echo "CODE_SIGN_IDENTITY=$identity"
  echo "DINGDONG_SIGNING_KEYCHAIN=$keychain_path"
} >> "$GITHUB_ENV"
