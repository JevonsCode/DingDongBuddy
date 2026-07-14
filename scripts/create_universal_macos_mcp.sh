#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ARM64_BUNDLE X86_64_BUNDLE OUTPUT_BUNDLE" >&2
  exit 64
fi

arm64_bundle="$1"
x86_64_bundle="$2"
output_bundle="$3"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/dingdong-universal-mcp.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

for bundle in "$arm64_bundle" "$x86_64_bundle"; do
  if [ ! -d "$bundle" ]; then
    echo "MCP bundle does not exist: $bundle" >&2
    exit 66
  fi
done

lipo_binary="${LIPO_BIN:-}"
if [ -z "$lipo_binary" ]; then
  xcode_lipo="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/lipo"
  if [ -x "$xcode_lipo" ]; then
    lipo_binary="$xcode_lipo"
  else
    lipo_binary="$(/usr/bin/xcrun --find lipo)"
  fi
fi

(cd "$arm64_bundle" && /usr/bin/find . -type f | LC_ALL=C /usr/bin/sort) \
  >"$temporary_directory/arm64-files"
(cd "$x86_64_bundle" && /usr/bin/find . -type f | LC_ALL=C /usr/bin/sort) \
  >"$temporary_directory/x86_64-files"

if ! /usr/bin/cmp -s \
  "$temporary_directory/arm64-files" \
  "$temporary_directory/x86_64-files"; then
  echo "The arm64 and x86_64 MCP bundles contain different files" >&2
  /usr/bin/diff -u \
    "$temporary_directory/arm64-files" \
    "$temporary_directory/x86_64-files" >&2 || true
  exit 65
fi

rm -rf "$output_bundle"
/usr/bin/ditto "$arm64_bundle" "$output_bundle"

mach_o_count=0
while IFS= read -r relative_path; do
  arm64_file="$arm64_bundle/$relative_path"
  x86_64_file="$x86_64_bundle/$relative_path"
  output_file="$output_bundle/$relative_path"
  arm64_description="$(/usr/bin/file -b "$arm64_file")"
  x86_64_description="$(/usr/bin/file -b "$x86_64_file")"

  case "$arm64_description" in
    *Mach-O*)
      case "$x86_64_description" in
        *Mach-O*) ;;
        *)
          echo "Architecture mismatch for $relative_path" >&2
          exit 65
          ;;
      esac
      "$lipo_binary" -create \
        "$arm64_file" \
        "$x86_64_file" \
        -output "$output_file"
      /bin/chmod "$(/usr/bin/stat -f '%Lp' "$arm64_file")" "$output_file"
      mach_o_count=$((mach_o_count + 1))
      ;;
    *)
      if ! /usr/bin/cmp -s "$arm64_file" "$x86_64_file"; then
        echo "Non-Mach-O bundle file differs by architecture: $relative_path" >&2
        exit 65
      fi
      ;;
  esac
done <"$temporary_directory/arm64-files"

if [ "$mach_o_count" -eq 0 ]; then
  echo "The MCP bundles did not contain any Mach-O files" >&2
  exit 65
fi

mcp_executable="$output_bundle/bin/dingdong_mcp"
if [ ! -f "$mcp_executable" ]; then
  echo "The Universal MCP executable was not produced: $mcp_executable" >&2
  exit 66
fi
# GitHub artifact downloads normalize regular-file permissions. Restore the
# entry point explicitly so the merged bundle is runnable after download.
/bin/chmod 755 "$mcp_executable"

while IFS= read -r relative_path; do
  output_file="$output_bundle/$relative_path"
  case "$(/usr/bin/file -b "$output_file")" in
    *Mach-O*)
      architectures="$("$lipo_binary" -archs "$output_file")"
      case " $architectures " in *" arm64 "*) ;; *) exit 65;; esac
      case " $architectures " in *" x86_64 "*) ;; *) exit 65;; esac
      echo "$relative_path: $architectures"
      ;;
  esac
done <"$temporary_directory/arm64-files"

echo "Created Universal DingDong MCP bundle with $mach_o_count Mach-O files"
