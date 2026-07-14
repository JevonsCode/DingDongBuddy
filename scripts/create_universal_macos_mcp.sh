#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ARM64_BUNDLE X86_64_BUNDLE OUTPUT_BUNDLE" >&2
  exit 64
fi

arm64_bundle="$1"
x86_64_bundle="$2"
output_bundle="$3"
repository_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
launcher="$repository_root/scripts/macos_mcp_launcher.sh"

for bundle in "$arm64_bundle" "$x86_64_bundle"; do
  if [ ! -d "$bundle" ]; then
    echo "MCP bundle does not exist: $bundle" >&2
    exit 66
  fi
done

if [ ! -f "$launcher" ]; then
  echo "MCP launcher does not exist: $launcher" >&2
  exit 66
fi

verify_native_bundle() {
  bundle="$1"
  expected_architecture="$2"
  other_architecture="$3"
  mach_o_count=0

  while IFS= read -r native_file; do
    description="$(/usr/bin/file -b "$native_file")"
    case "$description" in
      *Mach-O*)
        case "$description" in
          *"$expected_architecture"*) ;;
          *)
            echo "Native MCP file has the wrong architecture: $native_file: $description" >&2
            exit 65
            ;;
        esac
        case "$description" in
          *"$other_architecture"*)
            echo "Native MCP file unexpectedly contains $other_architecture: $native_file" >&2
            exit 65
            ;;
        esac
        mach_o_count=$((mach_o_count + 1))
        ;;
    esac
  done <<EOF
$(/usr/bin/find "$bundle" -type f | LC_ALL=C /usr/bin/sort)
EOF

  if [ "$mach_o_count" -eq 0 ]; then
    echo "The $expected_architecture MCP bundle did not contain any Mach-O files" >&2
    exit 65
  fi

  echo "Verified $mach_o_count native $expected_architecture MCP files"
}

verify_native_bundle "$arm64_bundle" arm64 x86_64
verify_native_bundle "$x86_64_bundle" x86_64 arm64

rm -rf "$output_bundle"
/bin/mkdir -p "$output_bundle/bin" "$output_bundle/native"
/usr/bin/ditto "$arm64_bundle" "$output_bundle/native/arm64"
/usr/bin/ditto "$x86_64_bundle" "$output_bundle/native/x86_64"
/usr/bin/ditto "$launcher" "$output_bundle/bin/dingdong_mcp"

# GitHub artifact downloads normalize regular-file permissions. Restore all
# entry points explicitly after copying the architecture-specific bundles.
/bin/chmod 755 \
  "$output_bundle/bin/dingdong_mcp" \
  "$output_bundle/native/arm64/bin/dingdong_mcp" \
  "$output_bundle/native/x86_64/bin/dingdong_mcp"

echo "Created a dual-architecture DingDong MCP bundle"
