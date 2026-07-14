#!/bin/sh
set -eu

bundle_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
machine_architecture="$(/usr/bin/uname -m)"

case "$machine_architecture" in
  arm64|x86_64) ;;
  *)
    echo "DingDong MCP does not support this macOS architecture: $machine_architecture" >&2
    exit 64
    ;;
esac

native_executable="$bundle_root/native/$machine_architecture/bin/dingdong_mcp"
if [ ! -x "$native_executable" ]; then
  echo "DingDong MCP executable is unavailable for $machine_architecture" >&2
  exit 66
fi

exec "$native_executable" "$@"
