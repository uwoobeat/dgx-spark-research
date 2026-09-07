#!/usr/bin/env bash
set -euo pipefail

source_file="${1:?usage: split-large-file.sh SOURCE_FILE OUTPUT_DIR}"
output_dir="${2:?usage: split-large-file.sh SOURCE_FILE OUTPUT_DIR}"

test -f "$source_file"
mkdir -p "$output_dir"

base="$(basename "$source_file")"
prefix="${output_dir}/${base}."
parts_manifest="${output_dir}/${base}.parts.tsv"
original_sha="$(sha256sum "$source_file" | awk '{print $1}')"
original_bytes="$(stat -c '%s' "$source_file")"

split --bytes=4294967296 --numeric-suffixes=0 --suffix-length=3 \
  --additional-suffix=.part -- "$source_file" "$prefix"

tmp="${parts_manifest}.tmp"
{
  printf '# original_path\t%s\n' "$base"
  printf '# original_bytes\t%s\n' "$original_bytes"
  printf '# original_sha256\t%s\n' "$original_sha"
  printf 'part\tbytes\tsha256\n'
  for part in "${prefix}"*.part; do
    printf '%s\t%s\t%s\n' \
      "$(basename "$part")" \
      "$(stat -c '%s' "$part")" \
      "$(sha256sum "$part" | awk '{print $1}')"
  done
} > "$tmp"
mv "$tmp" "$parts_manifest"
printf 'wrote %s\n' "$parts_manifest"

