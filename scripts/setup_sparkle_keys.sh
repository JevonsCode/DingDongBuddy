#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <private-key-export-path>" >&2
  echo "The export is secret. Keep it outside the repository." >&2
  exit 64
fi

private_key_path="$1"
if [[ -e "$private_key_path" ]]; then
  echo "Refusing to overwrite existing key export: $private_key_path" >&2
  exit 73
fi

sparkle_version="2.9.4"
sparkle_sha256="ce89daf967db1e1893ed3ebd67575ed82d3902563e3191ca92aaec9164fbdef9"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/dingdong-sparkle-keys.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

distribution_archive="$temporary_root/Sparkle-${sparkle_version}.tar.xz"
curl --fail --location --silent --show-error \
  "https://github.com/sparkle-project/Sparkle/releases/download/${sparkle_version}/Sparkle-${sparkle_version}.tar.xz" \
  --output "$distribution_archive"
actual_sha256="$(shasum -a 256 "$distribution_archive" | awk '{print $1}')"
if [[ "$actual_sha256" != "$sparkle_sha256" ]]; then
  echo "Sparkle distribution checksum mismatch" >&2
  exit 65
fi
tar -xf "$distribution_archive" -C "$temporary_root"

mkdir -p "$(dirname "$private_key_path")"
"$temporary_root/bin/generate_keys" --account com.dingdongbuddy.app
"$temporary_root/bin/generate_keys" \
  --account com.dingdongbuddy.app \
  -x "$private_key_path"
chmod 600 "$private_key_path"

echo
echo "Private key exported to: $private_key_path"
echo "Public key (store as the SPARKLE_PUBLIC_ED_KEY GitHub secret):"
"$temporary_root/bin/generate_keys" --account com.dingdongbuddy.app -p
echo
echo "Store the private export as the SPARKLE_PRIVATE_ED_KEY GitHub secret."
