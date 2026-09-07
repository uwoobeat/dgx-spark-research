#!/usr/bin/env bash
set -euo pipefail

root="${1:?usage: verify-sha-manifest.sh PAYLOAD_ROOT MANIFEST.sha256}"
manifest="${2:?usage: verify-sha-manifest.sh PAYLOAD_ROOT MANIFEST.sha256}"

root_abs="$(cd "$root" && pwd)"
manifest_abs="$(realpath "$manifest")"
(
  cd "$root_abs"
  sha256sum --check --strict "$manifest_abs"
)

