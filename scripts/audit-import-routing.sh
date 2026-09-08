#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
portal_files=(
  "$repo_root"/manifests/quarantine-*
)

for file in "${portal_files[@]}"; do
  test -f "$file" || { printf 'missing portal manifest: %s\n' "$file" >&2; exit 2; }
done

unexpected_raw="$(find "$repo_root/manifests" -maxdepth 1 -type f -name 'quarantine-raw-*' ! -name 'quarantine-raw-sources.tsv' -print -quit)"
if [[ -n "$unexpected_raw" ]]; then
  printf 'ERROR: unexpected quarantine RAW manifest (models/repository archives are forbidden): %s\n' "$unexpected_raw" >&2
  exit 3
fi

if grep -EHi 'huggingface\.co/|\.(safetensors|gguf)([?[:space:]]|$)|pytorch_model[^[:space:]]*\.bin' "${portal_files[@]}"; then
  printf 'ERROR: model payload reference found in quarantine portal manifests\n' >&2
  exit 3
fi

raw="$repo_root/manifests/quarantine-raw-sources.tsv"
if grep -EHi 'github\.com/.+/(archive|releases/download)/|\.tar\.(gz|xz)([?[:space:]]|$)|\.zip([?[:space:]]|$)' "$raw"; then
  printf 'ERROR: full repository/archive reference found in quarantine RAW manifest\n' >&2
  exit 3
fi

awk -F '\t' '
  NR == 1 {
    if ($1 != "item_id" || $2 != "url" || $7 != "bytes" || $8 != "sha256" || $9 != "import_route") {
      print "invalid quarantine RAW header" > "/dev/stderr"
      bad = 1
    }
    next
  }
  NF != 9 { printf "invalid RAW field count at row %d\n", NR > "/dev/stderr"; bad = 1 }
  $1 !~ /^R-0[1-6]$/ { printf "invalid RAW item id at row %d: %s\n", NR, $1 > "/dev/stderr"; bad = 1 }
  $2 !~ /^https:\/\/(raw\.githubusercontent\.com|files\.pythonhosted\.org)\// {
    printf "invalid RAW source URL at row %d: %s\n", NR, $2 > "/dev/stderr"; bad = 1
  }
  $1 != "R-06" && ($2 !~ /^https:\/\/raw\.githubusercontent\.com\// || $4 !~ /^[0-9a-f]{40}$/) {
    printf "GitHub RAW row is not pinned to a 40-character commit at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $1 == "R-06" && ($2 !~ /^https:\/\/files\.pythonhosted\.org\// || $4 != "6.0.3") {
    printf "PyYAML row has an unexpected source/version at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $7 !~ /^[0-9]+$/ || $7 + 0 >= 5000000000 {
    printf "invalid/oversize RAW payload at row %d: %s\n", NR, $7 > "/dev/stderr"; bad = 1
  }
  $8 !~ /^[0-9a-f]{64}$/ { printf "invalid RAW sha256 at row %d\n", NR > "/dev/stderr"; bad = 1 }
  $9 != "quarantine-raw" { printf "invalid RAW route at row %d\n", NR > "/dev/stderr"; bad = 1 }
  END {
    if (NR != 7) {
      printf "expected header plus 6 executable/wheel RAW rows, got %d lines\n", NR > "/dev/stderr"
      bad = 1
    }
    exit bad
  }
' "$raw"

required_oci="$repo_root/manifests/manual-oci-import.txt"
awk '
  NF != 1 || $0 !~ /@sha256:[0-9a-f]{64}$/ { printf "invalid required OCI ref at row %d\n", NR > "/dev/stderr"; bad = 1 }
  END {
    if (NR != 4) { printf "expected exactly 4 required OCI images, got %d\n", NR > "/dev/stderr"; bad = 1 }
    exit bad
  }
' "$required_oci"

attempt_result="$repo_root/manifests/quarantine-attempt-result.tsv"
test -f "$attempt_result" || { printf 'missing quarantine attempt result manifest\n' >&2; exit 4; }

awk -F '\t' '
  NR == 1 {
    if ($1 != "item_id" || $2 != "item_type" || $3 != "artifact_ref" ||
        $4 != "target" || $5 != "collection_result" ||
        $6 != "planned_route" || $7 != "planned_action" ||
        $8 != "security_or_scan_note" || $9 != "failure_reason") {
      print "invalid quarantine attempt result header" > "/dev/stderr"
      bad = 1
    }
    next
  }
  NF != 9 { printf "invalid attempt result field count at row %d\n", NR > "/dev/stderr"; bad = 1 }
  $2 == "OCI" && ($3 !~ /@sha256:[0-9a-f]{64}$/ || $4 != "DOCKER linux/arm64") {
    printf "invalid OCI attempt result at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $2 == "RAW" && ($3 !~ /^R-0[1-6]$/ || $4 != "RAW raw-any") {
    printf "invalid RAW attempt result at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $2 != "OCI" && $2 != "RAW" { printf "invalid attempt result type at row %d\n", NR > "/dev/stderr"; bad = 1 }
  $5 != "COLLECTION_SUCCESS" && $5 != "COLLECTION_FAILED" {
    printf "invalid collection result at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $2 == "RAW" && $6 != "current-quarantine-round" {
    printf "RAW artifact has an invalid current route at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $2 == "OCI" && $6 != "manual-oci-import" {
    printf "failed artifact is not routed to manual OCI import at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $2 == "OCI" { oci += 1 }
  $2 == "RAW" { raw += 1 }
  $5 == "COLLECTION_SUCCESS" { success += 1 }
  $5 == "COLLECTION_FAILED" { failure += 1 }
  END {
    if (NR != 11) { printf "expected header plus 10 attempt result rows, got %d lines\n", NR > "/dev/stderr"; bad = 1 }
    if (oci != 4 || raw != 6) { printf "expected 4 OCI + 6 RAW attempt result rows, got %d + %d\n", oci, raw > "/dev/stderr"; bad = 1 }
    if (success != 8 || failure != 2) { printf "expected 8 collection successes + 2 failures, got %d + %d\n", success, failure > "/dev/stderr"; bad = 1 }
    exit bad
  }
' "$attempt_result"

separate="$repo_root/manifests/separate-model-import.tsv"
test -f "$separate" || { printf 'missing separate model import manifest\n' >&2; exit 4; }

awk -F '\t' '
  NR == 1 { next }
  $10 != "no" || $11 != "separate-model-application" {
    printf "invalid model import route at row %d: %s\n", NR, $1 > "/dev/stderr"
    bad = 1
  }
  END {
    if (NR != 4) {
      printf "expected header plus 3 separately imported model rows, got %d lines\n", NR > "/dev/stderr"
      bad = 1
    }
    exit bad
  }
' "$separate"

external="$repo_root/manifests/external-repository-references.tsv"
test -f "$external" || { printf 'missing external repository reference manifest\n' >&2; exit 5; }

awk -F '\t' '
  NR == 1 {
    if ($1 != "item_id" || $6 != "quarantine_registration" || $7 != "import_route") {
      print "invalid external repository reference header" > "/dev/stderr"
      bad = 1
    }
    next
  }
  NF != 8 { printf "invalid external repository field count at row %d\n", NR > "/dev/stderr"; bad = 1 }
  $1 !~ /^E-0[1-7]$/ { printf "invalid external repository item id at row %d: %s\n", NR, $1 > "/dev/stderr"; bad = 1 }
  $2 !~ /^https:\/\/github\.com\// || $3 !~ /^[0-9a-f]{40}$/ {
    printf "external repository is not GitHub/commit-pinned at row %d\n", NR > "/dev/stderr"; bad = 1
  }
  $6 != "yes" || $7 != "quarantine-repository-round" {
    printf "invalid external repository route at row %d: %s\n", NR, $1 > "/dev/stderr"
    bad = 1
  }
  END {
    if (NR != 8) { printf "expected header plus 7 repository reference rows, got %d lines\n", NR > "/dev/stderr"; bad = 1 }
    exit bad
  }
' "$external"

while IFS=$'\t' read -r item_id repository rest; do
  [[ "$item_id" == "item_id" ]] && continue
  if grep -Fq -- "$repository" "$raw"; then
    printf 'ERROR: external repository URL is mixed into quarantine input: %s\n' "$item_id" >&2
    exit 5
  fi
done < "$external"

external_web="$repo_root/manifests/external-web-references.tsv"
web_count=0
if [[ -f "$external_web" ]]; then
  awk -F '\t' '
    NR == 1 {
      if ($1 != "item_id" || $3 != "url" || $10 != "snapshot_sha256" || $11 != "quarantine_registration" || $12 != "import_route") {
        print "invalid external web reference header" > "/dev/stderr"
        bad = 1
      }
      next
    }
    NF != 12 { printf "invalid external web reference field count at row %d\n", NR > "/dev/stderr"; bad = 1 }
    $1 !~ /^W-0[1-5]$/ { printf "invalid external web item id at row %d: %s\n", NR, $1 > "/dev/stderr"; bad = 1 }
    $2 !~ /^github-(issue|pull-request)$/ || $3 !~ /^https:\/\/github\.com\// {
      printf "invalid external web source at row %d\n", NR > "/dev/stderr"; bad = 1
    }
    $7 != "-" && $7 !~ /^[0-9a-f]{40}$/ {
      printf "invalid related commit at external web row %d\n", NR > "/dev/stderr"; bad = 1
    }
    $10 != "PENDING_AFTER_APPROVED_CAPTURE" && $10 !~ /^[0-9a-f]{64}$/ {
      printf "invalid external web snapshot digest at row %d\n", NR > "/dev/stderr"; bad = 1
    }
    $11 != "no" || $12 != "separate-external-web-reference-document-submission" {
      printf "invalid external web route at row %d: %s\n", NR, $1 > "/dev/stderr"
      bad = 1
    }
    END {
      if (NR != 6) { printf "expected header plus 5 external web reference rows, got %d lines\n", NR > "/dev/stderr"; bad = 1 }
      exit bad
    }
  ' "$external_web"

  while IFS=$'\t' read -r item_id source_type url rest; do
    [[ "$item_id" == "item_id" ]] && continue
    if grep -Fq -- "$url" "${portal_files[@]}"; then
      printf 'ERROR: external web reference URL is mixed into quarantine input: %s\n' "$item_id" >&2
      exit 5
    fi
    web_count=$((web_count + 1))
  done < "$external_web"
fi

python3 "$repo_root/scripts/validate-final-import-plan.py"
printf 'import routing verified: code round has 6 script/wheel RAW + 40 Python DEB RAW and zero OCI; source round has 8 repositories; manual import has 3 models + 4 OCI; %d web references deferred\n' "$web_count"
