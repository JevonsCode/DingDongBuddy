#!/bin/sh
set -eu

identity="${DINGDONG_LOCAL_SIGNING_IDENTITY:-DingDong Local Development}"
keychain="${DINGDONG_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if /usr/bin/security find-identity -v -p codesigning "$keychain" 2>/dev/null \
  | /usr/bin/grep -F "\"$identity\"" >/dev/null; then
  echo "Code-signing identity '$identity' already exists."
  exit 0
fi

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/dingdong-signing.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT HUP INT TERM

private_key="$temporary_directory/private-key.pem"
certificate="$temporary_directory/certificate.pem"
archive="$temporary_directory/identity.p12"
archive_password="$(/usr/bin/uuidgen | /usr/bin/tr -d '-')"

/usr/bin/openssl req \
  -new \
  -newkey rsa:2048 \
  -x509 \
  -sha256 \
  -days 3650 \
  -nodes \
  -subj "/CN=$identity/O=DingDong/OU=Local Development" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -keyout "$private_key" \
  -out "$certificate"

/usr/bin/openssl pkcs12 \
  -export \
  -name "$identity" \
  -inkey "$private_key" \
  -in "$certificate" \
  -out "$archive" \
  -passout "pass:$archive_password"

/usr/bin/security import "$archive" \
  -k "$keychain" \
  -P "$archive_password" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
/usr/bin/security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$keychain" \
  "$certificate"

if ! /usr/bin/security find-identity -v -p codesigning "$keychain" \
  | /usr/bin/grep -F "\"$identity\"" >/dev/null; then
  echo "Unable to create code-signing identity '$identity'." >&2
  exit 1
fi

echo "Created stable local code-signing identity '$identity'."
