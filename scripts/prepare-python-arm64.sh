#!/usr/bin/env bash
set -euo pipefail

# Online staging only; never installs packages or uses host dpkg status.
if [[ "${DGX_AGENT_MODE:-external}" != external ]]; then
  printf 'external mode required\n' >&2; exit 2
fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:---help}" in
  --help) printf 'Usage: prepare-python-arm64.sh --collect\nDownloads an isolated Ubuntu 24.04 ARM64 Python/pip dependency closure. No installation.\n'; exit 0 ;;
  --collect) ;;
  *) printf 'expected --collect or --help\n' >&2; exit 2 ;;
esac
for cmd in apt-get dpkg-deb python3; do command -v "$cmd" >/dev/null; done
test -f /usr/share/keyrings/ubuntu-archive-keyring.gpg
mkdir -p "$repo_root/staging"
work="$(mktemp -d "$repo_root/staging/python-arm64.XXXXXX")"
mkdir -p "$work/lists/partial" "$work/archives/partial" "$work/log"
touch "$work/status"
opts=(
  -o "Dir::Etc::sourcelist=$repo_root/manifests/python-arm64.sources"
  -o 'Dir::Etc::sourceparts=-'
  -o "Dir::State::status=$work/status"
  -o "Dir::State::lists=$work/lists"
  -o "Dir::Cache::archives=$work/archives"
  -o "Dir::Cache::pkgcache=$work/pkgcache.bin"
  -o "Dir::Cache::srcpkgcache=$work/srcpkgcache.bin"
  -o "Dir::Log=$work/log"
  -o 'APT::Architecture=arm64'
  -o 'APT::Install-Recommends=false'
  -o 'APT::Install-Suggests=false'
  -o 'Acquire::Languages=none'
  -o 'APT::Get::List-Cleanup=false'
)
apt-get "${opts[@]}" --error-on=any update
apt-get "${opts[@]}" --print-uris --yes --download-only install python3 python3.12 python3-pip > "$work/uris.txt"
apt-get "${opts[@]}" --yes --download-only install python3 python3.12 python3-pip
python3 "$repo_root/scripts/inventory-python-debs.py" "$work"
printf 'Collected under %s\nRetain signed indexes, URI list and archives; verify target DGX OS before offline install.\n' "$work"
