#!/usr/bin/env bash
set -euo pipefail

model_root="${1:?usage: make-model-tree-manifest.sh MODEL_ROOT OUTPUT.tsv}"
output="${2:?usage: make-model-tree-manifest.sh MODEL_ROOT OUTPUT.tsv}"
root_abs="$(cd "$model_root" && pwd)"
tmp="${output}.tmp"

{
  printf 'path\tbytes\tsha256\n'
  while IFS= read -r -d '' file; do
    rel="${file#./}"
    printf '%s\t%s\t%s\n' \
      "$rel" \
      "$(stat -c '%s' "$root_abs/$rel")" \
      "$(sha256sum "$root_abs/$rel" | awk '{print $1}')"
  done < <(cd "$root_abs" && find . -type f -print0 | LC_ALL=C sort -z)
} > "$tmp"
mv "$tmp" "$output"
printf 'wrote %s\n' "$output"

