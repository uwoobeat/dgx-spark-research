#!/usr/bin/env bash
set -euo pipefail

# Offline-only verifier for separately approved GitHub source trees.
# This script performs no HTTP, SSH, package-manager, registry, or git fetch.
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reference_manifest="$repo_root/manifests/external-repository-references.tsv"
upstream_root="$repo_root/third_party/upstreams"
require_all=no
write_id=''

usage() {
  cat <<'EOF'
Usage:
  verify-offline-repositories.sh [--require-all]
  verify-offline-repositories.sh --write-manifest E-0N

Default mode verifies every present stable-ID directory and skips absent ones.
--require-all is the closed-network intake gate for all approved repositories.
--write-manifest is an external-staging mutation and requires both:
  DGX_AGENT_MODE=external
  REPOSITORY_REFERENCE_COLLECTION_APPROVED=yes
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --require-all)
      [[ -z "$write_id" ]] || die '--require-all and --write-manifest are mutually exclusive'
      require_all=yes
      shift
      ;;
    --write-manifest)
      [[ "$require_all" = no ]] || die '--require-all and --write-manifest are mutually exclusive'
      (($# >= 2)) || die '--write-manifest requires an E-ID'
      write_id="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -f "$reference_manifest" ]] || die "missing reference manifest: $reference_manifest"
if [[ -n "$write_id" ]]; then
  [[ "${DGX_AGENT_MODE:-external}" = external ]] || \
    die '--write-manifest is allowed only in DGX_AGENT_MODE=external'
  [[ "${REPOSITORY_REFERENCE_COLLECTION_APPROVED:-no}" = yes ]] || \
    die '--write-manifest requires REPOSITORY_REFERENCE_COLLECTION_APPROVED=yes'
  [[ "$write_id" =~ ^E-0[1-9][0-9]*$ ]] || die "invalid stable ID: $write_id"
fi

python_tree_manifest() {
  local action="$1"
  local tree_root="$2"

  python3 - "$action" "$tree_root" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

action = sys.argv[1]
root = Path(sys.argv[2])
manifest_path = root / ".source-tree.sha256"
metadata = {
    ".source-url",
    ".source-commit",
    ".source-tree.sha256",
    ".source-tree.sha256.digest",
    ".license-review.txt",
}

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def inventory():
    records = []
    for directory, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
        current = Path(directory)
        rel_dir = current.relative_to(root)
        if rel_dir == Path("."):
            dirnames[:] = [name for name in dirnames if name != ".git"]
        for name in list(dirnames):
            path = current / name
            if path.is_symlink():
                dirnames.remove(name)
                filenames.append(name)
        for name in filenames:
            path = current / name
            rel = path.relative_to(root).as_posix()
            if rel in metadata or rel == ".git" or rel.startswith(".git/"):
                continue
            if any(character in rel for character in ("\t", "\n", "\r")):
                raise ValueError(f"unsupported control character in path: {rel!r}")
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                target = os.readlink(path).encode("utf-8")
                records.append((rel, "L", sha256_bytes(target)))
            elif stat.S_ISREG(mode):
                records.append((rel, "F", sha256_file(path)))
            else:
                raise ValueError(f"unsupported filesystem entry: {rel}")
    records.sort(key=lambda record: record[0].encode("utf-8"))
    return records

try:
    actual = inventory()
    if action == "write":
        temporary = root / ".source-tree.sha256.tmp"
        with temporary.open("w", encoding="utf-8", newline="\n") as stream:
            for rel, kind, digest in actual:
                stream.write(f"{kind}\t{digest}\t{rel}\n")
        os.replace(temporary, manifest_path)
        raise SystemExit(0)

    if action != "verify":
        raise ValueError(f"unknown manifest action: {action}")
    if not manifest_path.is_file():
        raise ValueError("missing .source-tree.sha256")

    expected = []
    seen = set()
    for number, line in enumerate(manifest_path.read_text(encoding="utf-8").splitlines(), 1):
        fields = line.split("\t")
        if len(fields) != 3:
            raise ValueError(f"invalid tree manifest field count at line {number}")
        kind, digest, rel = fields
        if kind not in {"F", "L"} or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise ValueError(f"invalid tree manifest record at line {number}")
        if not rel or rel.startswith("/") or ".." in Path(rel).parts or rel in metadata or rel.startswith(".git/"):
            raise ValueError(f"unsafe or reserved path at line {number}: {rel}")
        if rel in seen:
            raise ValueError(f"duplicate tree manifest path at line {number}: {rel}")
        seen.add(rel)
        expected.append((rel, kind, digest))

    if expected != actual:
        expected_map = {rel: (kind, digest) for rel, kind, digest in expected}
        actual_map = {rel: (kind, digest) for rel, kind, digest in actual}
        missing = sorted(set(expected_map) - set(actual_map))
        extra = sorted(set(actual_map) - set(expected_map))
        changed = sorted(
            rel for rel in set(expected_map) & set(actual_map)
            if expected_map[rel] != actual_map[rel]
        )
        raise ValueError(
            "tree manifest mismatch: "
            f"missing={missing[:5]} extra={extra[:5]} changed={changed[:5]}"
        )
except (OSError, UnicodeError, ValueError) as error:
    print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
}

verify_identity_and_license() {
  local stable_id="$1"
  local repository="$2"
  local pin="$3"
  local license_status="$4"
  local directory="$upstream_root/$stable_id"
  local recorded_url recorded_pin actual_pin

  [[ ! -L "$directory" ]] || die "$stable_id directory must not be a symlink"
  [[ -d "$directory" ]] || die "$stable_id directory is missing: $directory"
  [[ -f "$directory/.source-url" ]] || die "$stable_id is missing .source-url"
  recorded_url="$(<"$directory/.source-url")"
  [[ "$recorded_url" = "$repository" ]] || die "$stable_id source URL does not match the manifest"

  if [[ -d "$directory/.git" ]] || [[ -f "$directory/.git" ]]; then
    command -v git >/dev/null 2>&1 || die "$stable_id has Git metadata but git is unavailable"
    actual_pin="$(git -C "$directory" rev-parse --verify HEAD^{commit})" || \
      die "$stable_id Git HEAD cannot be resolved"
    [[ "$actual_pin" = "$pin" ]] || die "$stable_id Git HEAD $actual_pin does not match pin $pin"
    git -C "$directory" diff-index --quiet HEAD -- || die "$stable_id has modified tracked files"
    if [[ -f "$directory/.source-commit" ]]; then
      recorded_pin="$(<"$directory/.source-commit")"
      [[ "$recorded_pin" = "$pin" ]] || die "$stable_id .source-commit does not match the manifest"
    fi
  else
    [[ -f "$directory/.source-commit" ]] || die "$stable_id archive is missing .source-commit"
    recorded_pin="$(<"$directory/.source-commit")"
    [[ "$recorded_pin" = "$pin" ]] || die "$stable_id .source-commit does not match the manifest"
  fi

  if [[ "$license_status" = NOASSERTION ]]; then
    [[ -s "$directory/.license-review.txt" ]] || \
      die "$stable_id NOASSERTION source is missing .license-review.txt"
    grep -Fq 'NOASSERTION' "$directory/.license-review.txt" || \
      die "$stable_id license review does not preserve NOASSERTION status"
  else
    find "$directory" -maxdepth 1 -type f \
      \( -iname 'LICENSE' -o -iname 'LICENSE.*' -o -iname 'COPYING' -o -iname 'COPYING.*' \) \
      -print -quit | grep -q . || die "$stable_id is missing a root LICENSE/COPYING file"
  fi
}

verify_tree_manifest() {
  local stable_id="$1"
  local directory="$upstream_root/$stable_id"
  local expected_digest actual_digest

  [[ -f "$directory/.source-tree.sha256" ]] || die "$stable_id is missing .source-tree.sha256"
  [[ -f "$directory/.source-tree.sha256.digest" ]] || \
    die "$stable_id is missing .source-tree.sha256.digest"
  expected_digest="$(<"$directory/.source-tree.sha256.digest")"
  [[ "$expected_digest" =~ ^[0-9a-f]{64}$ ]] || \
    die "$stable_id has an invalid tree-manifest digest"
  actual_digest="$(sha256sum "$directory/.source-tree.sha256" | awk '{print $1}')"
  [[ "$actual_digest" = "$expected_digest" ]] || \
    die "$stable_id tree-manifest digest mismatch"
  python_tree_manifest verify "$directory" || die "$stable_id file-tree verification failed"
}

declare -A seen_ids=()
declare -A manifest_urls=()
declare -A manifest_pins=()
declare -A manifest_licenses=()
manifest_count=0

while IFS=$'\t' read -r stable_id repository pin reference_role license_status quarantine_registration import_route portal_raw_subset; do
  if [[ "$stable_id" = item_id ]]; then
    [[ "$repository" = repository && "$pin" = pin ]] || die 'invalid reference manifest header'
    continue
  fi
  [[ "$stable_id" =~ ^E-0[1-9][0-9]*$ ]] || die "invalid stable ID in manifest: $stable_id"
  [[ -z "${seen_ids[$stable_id]:-}" ]] || die "duplicate stable ID in manifest: $stable_id"
  [[ "$repository" =~ ^https://github\.com/.+\.git$ ]] || die "$stable_id is not a GitHub .git URL"
  [[ "$pin" =~ ^[0-9a-f]{40}$ ]] || die "$stable_id pin is not a 40-character commit"
  [[ "$quarantine_registration" = no ]] || die "$stable_id must not use quarantine registration"
  [[ "$import_route" = separate-external-repository-reference-submission ]] || \
    die "$stable_id has an invalid import route"
  seen_ids[$stable_id]=1
  manifest_urls[$stable_id]="$repository"
  manifest_pins[$stable_id]="$pin"
  manifest_licenses[$stable_id]="$license_status"
  manifest_count=$((manifest_count + 1))
done < "$reference_manifest"

[[ "$manifest_count" -gt 0 ]] || die 'reference manifest contains no approved repository rows'
if [[ -n "$write_id" && -z "${seen_ids[$write_id]:-}" ]]; then
  die "$write_id is not present in the approved reference manifest"
fi

verified=0
skipped=0
for stable_id in $(printf '%s\n' "${!seen_ids[@]}" | sort); do
  directory="$upstream_root/$stable_id"
  if [[ ! -e "$directory" ]]; then
    if [[ "$require_all" = yes || "$write_id" = "$stable_id" ]]; then
      die "$stable_id directory is required but absent: $directory"
    fi
    printf 'SKIP %s absent (expected during external research before approved collection)\n' "$stable_id"
    skipped=$((skipped + 1))
    continue
  fi

  verify_identity_and_license \
    "$stable_id" "${manifest_urls[$stable_id]}" "${manifest_pins[$stable_id]}" \
    "${manifest_licenses[$stable_id]}"

  if [[ "$write_id" = "$stable_id" ]]; then
    python_tree_manifest write "$directory" || die "$stable_id tree manifest generation failed"
    sha256sum "$directory/.source-tree.sha256" | awk '{print $1}' \
      > "$directory/.source-tree.sha256.digest"
  fi

  verify_tree_manifest "$stable_id"
  printf 'PASS %s pin, license evidence, and complete file tree verified\n' "$stable_id"
  verified=$((verified + 1))
done

if [[ -n "$write_id" ]]; then
  printf 'manifest written and verified for %s; copy its digest into the separately approved submission/media record\n' "$write_id"
else
  printf 'offline repository verification complete: verified=%d skipped=%d require_all=%s\n' \
    "$verified" "$skipped" "$require_all"
fi
