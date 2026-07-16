#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /path/to/DingDong.app arm64|x86_64" >&2
  exit 64
fi

app_path="$1"
target_architecture="$2"

case "$target_architecture" in
  arm64)
    other_architecture=x86_64
    ;;
  x86_64)
    other_architecture=arm64
    ;;
  *)
    echo "Unsupported macOS architecture: $target_architecture" >&2
    exit 64
    ;;
esac

if [ ! -d "$app_path" ]; then
  echo "App bundle does not exist: $app_path" >&2
  exit 66
fi

mach_o_count=0
thinned_count=0

while IFS= read -r native_file; do
  description="$(/usr/bin/file -b "$native_file")"
  case "$description" in
    *Mach-O*) ;;
    *) continue ;;
  esac

  architectures="$(/usr/bin/lipo -archs "$native_file")"
  case " $architectures " in
    *" $target_architecture "*) ;;
    *)
      echo "Mach-O file does not contain $target_architecture: $native_file: $architectures" >&2
      exit 65
      ;;
  esac

  case " $architectures " in
    *" $other_architecture "*)
      temporary_file="$native_file.thin.$$"
      mode="$(/usr/bin/stat -f '%Lp' "$native_file")"
      /usr/bin/lipo "$native_file" \
        -thin "$target_architecture" \
        -output "$temporary_file"
      /bin/chmod "$mode" "$temporary_file"
      /usr/bin/touch -r "$native_file" "$temporary_file"
      /bin/mv "$temporary_file" "$native_file"
      thinned_count=$((thinned_count + 1))
      ;;
  esac

  resulting_architectures="$(/usr/bin/lipo -archs "$native_file")"
  if [ "$resulting_architectures" != "$target_architecture" ]; then
    echo "Mach-O file was not reduced to $target_architecture: $native_file: $resulting_architectures" >&2
    exit 65
  fi
  mach_o_count=$((mach_o_count + 1))
done <<EOF
$(/usr/bin/find "$app_path" -type f | LC_ALL=C /usr/bin/sort)
EOF

if [ "$mach_o_count" -eq 0 ]; then
  echo "App bundle did not contain any Mach-O files: $app_path" >&2
  exit 65
fi

echo "Verified $mach_o_count $target_architecture Mach-O files; thinned $thinned_count universal files"
