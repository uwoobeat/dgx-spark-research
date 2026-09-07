#!/usr/bin/env bash
set -euo pipefail

repo="${1:?usage: generate-hf-source-manifest.sh ORG/MODEL REVISION OUTPUT.tsv}"
revision="${2:?usage: generate-hf-source-manifest.sh ORG/MODEL REVISION OUTPUT.tsv}"
output="${3:?usage: generate-hf-source-manifest.sh ORG/MODEL REVISION OUTPUT.tsv}"

command -v curl >/dev/null
command -v jq >/dev/null

api_url="https://huggingface.co/api/models/${repo}/revision/${revision}?blobs=true"
resolve_base="https://huggingface.co/${repo}/resolve/${revision}/"
tmp="${output}.tmp"

curl -fsSL "$api_url" | jq -r --arg revision "$revision" --arg base "$resolve_base" '
  if .sha != $revision then
    error("resolved revision does not match requested revision")
  else
    (["path", "bytes", "upstream_lfs_sha256", "over_5gb_decimal", "url"] | @tsv),
    (.siblings[] |
      [
        .rfilename,
        ((.size // .lfs.size // 0) | tostring),
        (.lfs.sha256 // ""),
        (if (.size // .lfs.size // 0) > 5000000000 then "yes" else "no" end),
        ($base + (.rfilename | gsub(" "; "%20")) + "?download=true")
      ] | @tsv)
  end
' > "$tmp"

mv "$tmp" "$output"
printf 'wrote source inventory %s (not a quarantine RAW upload list)\n' "$output"
awk -F '\t' 'NR > 1 {bytes += $2; if ($4 == "yes") over++} END {printf "files=%d bytes=%.0f over_5GB=%d\n", NR-1, bytes, over+0}' "$output"
