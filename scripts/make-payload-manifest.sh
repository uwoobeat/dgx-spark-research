#!/usr/bin/env bash
set -euo pipefail

root="${1:?usage: make-payload-manifest.sh PAYLOAD_ROOT OUTPUT.sha256}"
output="${2:?usage: make-payload-manifest.sh PAYLOAD_ROOT OUTPUT.sha256}"

root_abs="$(cd "$root" && pwd)"
output_abs="$(realpath -m "$output")"
case "$output_abs" in
  "$root_abs"/*) echo "output manifest must be outside payload root" >&2; exit 2 ;;
esac

tmp="${output_abs}.tmp"
(
  cd "$root_abs"
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
) > "$tmp"
mv "$tmp" "$output_abs"
printf 'wrote %s\n' "$output_abs"

