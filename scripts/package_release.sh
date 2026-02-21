#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

target=""
binary=""
out_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --binary) binary="$2"; shift 2 ;;
    --out-dir) out_dir="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$target" ] || [ -z "$binary" ] || [ -z "$out_dir" ]; then
  echo "Usage: package_release.sh --target <target> --binary <path> --out-dir <dir>"
  exit 1
fi

case "$binary" in
  /*) ;;
  *) binary="$repo_root/$binary" ;;
esac

case "$out_dir" in
  /*) ;;
  *) out_dir="$repo_root/$out_dir" ;;
esac

mkdir -p "$out_dir"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cp "$binary" "$tmp_dir/nyx"

mkdir -p "$tmp_dir/scripts"
cp "$repo_root/scripts/nypm.sh" "$tmp_dir/scripts/"
cp "$repo_root/scripts/nyfmt.sh" "$tmp_dir/scripts/"
cp "$repo_root/scripts/nylint.sh" "$tmp_dir/scripts/"
cp "$repo_root/scripts/nydbg.sh" "$tmp_dir/scripts/"

mkdir -p "$tmp_dir/stdlib"
cp "$repo_root/stdlib/types.ny" "$tmp_dir/stdlib/"
cp "$repo_root/stdlib/class.ny" "$tmp_dir/stdlib/"

mkdir -p "$tmp_dir/compiler"
cp "$repo_root/compiler/bootstrap.ny" "$tmp_dir/compiler/"

mkdir -p "$tmp_dir/examples"
cp "$repo_root/examples/fibonacci.ny" "$tmp_dir/examples/"

if [ -f "$repo_root/README.md" ]; then
  cp "$repo_root/README.md" "$tmp_dir/"
fi

archive_name="nyx-$target.tar.gz"
tar -czf "$out_dir/$archive_name" -C "$tmp_dir" .

cd "$out_dir"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$archive_name" > "$archive_name.sha256"
else
  shasum -a 256 "$archive_name" > "$archive_name.sha256"
fi

echo "Created $out_dir/$archive_name"
