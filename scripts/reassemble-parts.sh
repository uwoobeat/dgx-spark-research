#!/usr/bin/env bash
set -euo pipefail

manifest="${1:?usage: reassemble-parts.sh PARTS.tsv OUTPUT_FILE}"
output_file="${2:?usage: reassemble-parts.sh PARTS.tsv OUTPUT_FILE}"

test -f "$manifest"
manifest_dir="$(cd "$(dirname "$manifest")" && pwd)"
expected_bytes="$(awk -F '\t' '$1 == "# original_bytes" {print $2}' "$manifest")"
expected_sha="$(awk -F '\t' '$1 == "# original_sha256" {print $2}' "$manifest")"
test -n "$expected_bytes"
test -n "$expected_sha"

mkdir -p "$(dirname "$output_file")"
tmp="${output_file}.tmp"
: > "$tmp"

while IFS=$'\t' read -r part bytes sha; do
  case "$part" in
    \#*|part|'') continue ;;
  esac
  file="${manifest_dir}/${part}"
  test -f "$file"
  test "$(stat -c '%s' "$file")" = "$bytes"
  test "$(sha256sum "$file" | awk '{print $1}')" = "$sha"
  cat -- "$file" >> "$tmp"
done < "$manifest"

test "$(stat -c '%s' "$tmp")" = "$expected_bytes"
test "$(sha256sum "$tmp" | awk '{print $1}')" = "$expected_sha"
mv "$tmp" "$output_file"
printf 'verified and wrote %s\n' "$output_file"

