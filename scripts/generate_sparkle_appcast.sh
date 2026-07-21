#!/bin/bash

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <update.zip> <appcast.xml> <download-url-prefix> <private-key-file>" >&2
  exit 64
fi

archive_path="$1"
output_path="$2"
download_url_prefix="$3"
private_key_path="$4"

if [[ ! -f "$archive_path" ]]; then
  echo "Update archive not found: $archive_path" >&2
  exit 66
fi
if [[ ! -s "$private_key_path" ]]; then
  echo "Sparkle private key not found: $private_key_path" >&2
  exit 66
fi

sparkle_version="2.9.4"
sparkle_sha256="ce89daf967db1e1893ed3ebd67575ed82d3902563e3191ca92aaec9164fbdef9"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/dingdong-sparkle.XXXXXX")"
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
staging_directory="$temporary_root/update"
mkdir -p "$staging_directory"
cp "$archive_path" "$staging_directory/"

output_directory="$(dirname "$output_path")"
mkdir -p "$output_directory"
output_directory="$(cd "$output_directory" && pwd)"
output_path="$output_directory/$(basename "$output_path")"

"$temporary_root/bin/generate_appcast" \
  --ed-key-file "$private_key_path" \
  --download-url-prefix "$download_url_prefix" \
  --link "https://github.com/JevonsCode/DingDongBuddy" \
  --maximum-versions 1 \
  -o "$output_path" \
  "$staging_directory"

test -s "$output_path"
grep -q 'sparkle:edSignature=' "$output_path"
