#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 OUTPUT_DIRECTORY EXPECTED_ARCHITECTURE" >&2
  exit 64
fi

output_directory="$1"
expected_architecture="$2"
repository_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
dart_binary="${DART_BIN:-${FLUTTER_ROOT:-}/bin/cache/dart-sdk/bin/dart}"

case "$expected_architecture" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported macOS architecture: $expected_architecture" >&2
    exit 64
    ;;
esac

if [ ! -x "$dart_binary" ]; then
  echo "Dart executable is unavailable: $dart_binary" >&2
  exit 69
fi

rm -rf "$output_directory"
cd "$repository_root"
"$dart_binary" build cli \
  --target=bin/dingdong_mcp.dart \
  --output="$output_directory" \
  --verbosity=warning

executable="$output_directory/bundle/bin/dingdong_mcp"
if [ ! -x "$executable" ]; then
  echo "DingDong MCP executable was not produced: $executable" >&2
  exit 66
fi

description="$(/usr/bin/file -b "$executable")"
case "$description" in
  *" $expected_architecture"*) ;;
  *)
    echo "DingDong MCP has the wrong architecture: $description" >&2
    exit 65
    ;;
esac

smoke_output="$(mktemp "${TMPDIR:-/tmp}/dingdong-mcp-smoke.XXXXXX")"
smoke_home="$(mktemp -d "${TMPDIR:-/tmp}/dingdong-mcp-smoke-home.XXXXXX")"
trap 'rm -f "$smoke_output"; rmdir "$smoke_home" 2>/dev/null || true' EXIT HUP INT TERM
/usr/bin/printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | "$executable" >"$smoke_output"

if ! /usr/bin/grep -q '"result"' "$smoke_output" \
  || ! /usr/bin/grep -q '"tools"' "$smoke_output"; then
  echo "DingDong MCP tools/list smoke test failed" >&2
  exit 70
fi

# Stop hooks expect an exit-zero, output-free command even if DingDong is not
# currently running. Use an isolated home so this build-time smoke test cannot
# connect to a running DingDong instance or pollute the user's Agent history.
/usr/bin/printf '%s' '{"hook_event_name":"Stop"}' \
  | HOME="$smoke_home" "$executable" --notify-stop

echo "Built and tested DingDong MCP for $expected_architecture"
