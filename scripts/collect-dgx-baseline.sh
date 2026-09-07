#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:?usage: collect-dgx-baseline.sh OUTPUT_DIR}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
report="$output_dir/summary.txt"
tmp="${report}.tmp"

run() {
  local title="$1"
  shift
  printf '\n## %s\n' "$title"
  "$@" 2>&1 || printf '[command unavailable or failed: %s]\n' "$*"
}

{
  printf '# DGX Spark baseline\n'
  printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run hostname hostnamectl
  run architecture uname -a
  run os-release sh -c 'test -f /etc/os-release && sed -n "1,80p" /etc/os-release'
  run dgx-release sh -c 'for f in /etc/dgx-release /etc/nvidia-container-runtime/config.toml; do test -f "$f" && { echo "[$f]"; sed -n "1,160p" "$f"; }; done'
  run cpu lscpu
  run nvidia-smi nvidia-smi -q
  run docker-version docker version
  run docker-info docker info
  run nvidia-container-cli nvidia-container-cli info
  run kernel-modules sh -c 'lsmod | sort'
  run packages sh -c 'dpkg-query -W -f="\${binary:Package}\t\${Version}\n" | grep -E "^(docker|containerd|nvidia|cuda|libnccl|rdma|ibverbs|mlx)" | sort'
  run required-commands sh -c '
    for cmd in bash awk sed grep find sort xargs sha256sum split stat readlink curl jq docker ip ss ping rdma ibdev2netdev swapon systemctl nvidia-smi; do
      path=$(command -v "$cmd" 2>/dev/null || true)
      if [ -z "$path" ]; then
        printf "%s\tMISSING\n" "$cmd"
        continue
      fi
      owner=$(dpkg-query -S "$path" 2>/dev/null | head -n 1 || true)
      printf "%s\t%s\t%s\n" "$cmd" "$path" "${owner:-package-owner-unknown}"
    done
  '
  run network ip -details -statistics address
  run routes ip route show table all
  run rdma-link rdma link
  run rdma-dev rdma dev
  run ibdev2netdev ibdev2netdev -v
  run firmware fwupdmgr get-devices
  run memory free -h
  run swap swapon --show --bytes
  run swappiness sysctl vm.swappiness
  run storage lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
  run filesystems df -hT
} > "$tmp"

mv "$tmp" "$report"
chmod 600 "$report"
printf 'wrote %s\n' "$report"
