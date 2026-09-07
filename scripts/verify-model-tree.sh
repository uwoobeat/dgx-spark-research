#!/usr/bin/env bash
set -euo pipefail

model_root="${1:?usage: verify-model-tree.sh MODEL_ROOT MANIFEST.tsv}"
manifest="${2:?usage: verify-model-tree.sh MODEL_ROOT MANIFEST.tsv}"
root_abs="$(cd "$model_root" && pwd)"

while IFS=$'\t' read -r path bytes sha; do
  case "$path" in
    path|'') continue ;;
  esac
  file="$root_abs/$path"
  test -f "$file" || { echo "missing: $path" >&2; exit 3; }
  test "$(stat -c '%s' "$file")" = "$bytes" || { echo "size mismatch: $path" >&2; exit 4; }
  test "$(sha256sum "$file" | awk '{print $1}')" = "$sha" || { echo "sha256 mismatch: $path" >&2; exit 5; }
done < "$manifest"

printf 'model tree verified: %s\n' "$root_abs"

