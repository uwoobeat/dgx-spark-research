#!/usr/bin/env bash
set -euo pipefail

profile_file="${1:?usage: preflight-dgx-node.sh PROFILE.sh NODE.env}"
node_env_file="${2:?usage: preflight-dgx-node.sh PROFILE.sh NODE.env}"

test -f "$profile_file" || { printf 'profile missing: %s\n' "$profile_file" >&2; exit 2; }
test -f "$node_env_file" || { printf 'node env missing: %s\n' "$node_env_file" >&2; exit 2; }

for cmd in awk grep sha256sum stat jq docker ip ss ping rdma ibdev2netdev swapon sysctl nvidia-smi; do
  command -v "$cmd" >/dev/null || { printf 'required command missing: %s\n' "$cmd" >&2; exit 3; }
done

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) printf 'host architecture must be aarch64/arm64, got %s\n' "$(uname -m)" >&2; exit 4 ;;
esac

env_mode="$(stat -c '%a' "$node_env_file")"
if (( (8#$env_mode & 077) != 0 )); then
  printf 'node env must not be group/world accessible: %s mode=%s\n' "$node_env_file" "$env_mode" >&2
  exit 5
fi

# shellcheck source=/dev/null
source "$node_env_file"
# shellcheck source=/dev/null
source "$profile_file"

: "${PROFILE_ID:?profile must set PROFILE_ID}"
: "${CONTAINER_NAME:?profile must set CONTAINER_NAME}"
: "${IMAGE_REF:?profile must set IMAGE_REF}"
: "${IMAGE_CONFIG_DIGEST:?profile must set IMAGE_CONFIG_DIGEST}"
: "${MODEL_CONFIG_JQ_FILTER:?profile must set MODEL_CONFIG_JQ_FILTER}"
: "${NODE_RANK:?node env must set NODE_RANK}"
: "${HEAD_FABRIC_IP:?node env must set HEAD_FABRIC_IP}"
: "${THIS_FABRIC_IP:?node env must set THIS_FABRIC_IP}"
: "${PEER_FABRIC_IP:?node env must set PEER_FABRIC_IP}"
: "${FABRIC_CIDR:?node env must set FABRIC_CIDR}"
: "${FABRIC_IFACE:?node env must set FABRIC_IFACE}"
: "${RDMA_HCA:?node env must set RDMA_HCA}"
: "${MASTER_PORT:?node env must set MASTER_PORT}"
: "${MODEL_HOST_PATH:?node env must set MODEL_HOST_PATH}"
: "${MODEL_TREE_MANIFEST:?node env must set MODEL_TREE_MANIFEST}"
: "${MODEL_TREE_MANIFEST_SHA256:?node env must set MODEL_TREE_MANIFEST_SHA256}"

case "$NODE_RANK" in 0|1) ;; *) printf 'NODE_RANK must be 0 or 1\n' >&2; exit 6 ;; esac
test "$THIS_FABRIC_IP" != "$PEER_FABRIC_IP" || { printf 'THIS_FABRIC_IP and PEER_FABRIC_IP must differ\n' >&2; exit 6; }
test "$FABRIC_CIDR" != "${FABRIC_CIDR#*/}" || { printf 'FABRIC_CIDR must include a prefix length\n' >&2; exit 6; }

ip link show dev "$FABRIC_IFACE" >/dev/null
ip -o -4 addr show dev "$FABRIC_IFACE" | awk -v expected="$THIS_FABRIC_IP" '
  { split($4, address, "/"); if (address[1] == expected) found = 1 }
  END { exit !found }
' || { printf 'fabric interface %s does not own %s\n' "$FABRIC_IFACE" "$THIS_FABRIC_IP" >&2; exit 7; }

route="$(ip -4 route get "$PEER_FABRIC_IP")"
grep -Eq "(^| )dev ${FABRIC_IFACE}( |$)" <<<"$route" || { printf 'peer route does not use %s: %s\n' "$FABRIC_IFACE" "$route" >&2; exit 7; }
grep -Eq "(^| )src ${THIS_FABRIC_IP}( |$)" <<<"$route" || { printf 'peer route does not source from %s: %s\n' "$THIS_FABRIC_IP" "$route" >&2; exit 7; }
ping -I "$FABRIC_IFACE" -c 2 -W 2 "$PEER_FABRIC_IP" >/dev/null || { printf 'peer fabric ping failed: %s\n' "$PEER_FABRIC_IP" >&2; exit 7; }

test -e /dev/infiniband || { printf '/dev/infiniband is missing\n' >&2; exit 8; }
rdma link show | grep -F "$RDMA_HCA" >/dev/null || { printf 'RDMA HCA not present in rdma link: %s\n' "$RDMA_HCA" >&2; exit 8; }
ibdev2netdev | awk -v hca="$RDMA_HCA" -v iface="$FABRIC_IFACE" '
  $1 == hca && $0 ~ ("==> " iface " ") { found = 1 }
  END { exit !found }
' || { printf 'HCA %s is not mapped to interface %s\n' "$RDMA_HCA" "$FABRIC_IFACE" >&2; exit 8; }

case "${PROFILE_SWAP_POLICY:-disabled}" in
  disabled)
    test -z "$(swapon --noheadings --show=NAME)" || { printf 'swap must be disabled for profile %s\n' "$PROFILE_ID" >&2; exit 9; }
    ;;
  enabled-swappiness-zero)
    test -n "$(swapon --noheadings --show=NAME)" || { printf 'active swap is required for profile %s\n' "$PROFILE_ID" >&2; exit 9; }
    test "$(sysctl -n vm.swappiness)" = "0" || { printf 'vm.swappiness must be 0 for profile %s\n' "$PROFILE_ID" >&2; exit 9; }
    ;;
  *)
    printf 'unknown PROFILE_SWAP_POLICY: %s\n' "$PROFILE_SWAP_POLICY" >&2
    exit 9
    ;;
esac
ss -ltnH | awk -v port=":${MASTER_PORT}" '$4 ~ (port "$") { found=1 } END { exit found }' || { printf 'master port already in use: %s\n' "$MASTER_PORT" >&2; exit 9; }
if test "$NODE_RANK" = 0; then
  ss -ltnH | awk '$4 ~ /:8000$/ { found=1 } END { exit found }' || { printf 'API port 8000 is already in use\n' >&2; exit 9; }
fi

test -f "$MODEL_HOST_PATH/config.json" || { printf 'model config missing: %s/config.json\n' "$MODEL_HOST_PATH" >&2; exit 10; }
jq -e "$MODEL_CONFIG_JQ_FILTER" "$MODEL_HOST_PATH/config.json" >/dev/null || {
  printf 'model config does not match profile %s: %s\n' "$PROFILE_ID" "$MODEL_HOST_PATH/config.json" >&2
  exit 10
}

test -f "$MODEL_TREE_MANIFEST" || { printf 'model tree manifest missing: %s\n' "$MODEL_TREE_MANIFEST" >&2; exit 10; }
[[ "$MODEL_TREE_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] || { printf 'MODEL_TREE_MANIFEST_SHA256 must be 64 lowercase hex characters\n' >&2; exit 10; }
test "$(sha256sum "$MODEL_TREE_MANIFEST" | awk '{print $1}')" = "$MODEL_TREE_MANIFEST_SHA256" || { printf 'approved model tree manifest SHA-256 mismatch\n' >&2; exit 10; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/verify-model-tree.sh" "$MODEL_HOST_PATH" "$MODEL_TREE_MANIFEST"

if test "${DRAFT_MODEL_REQUIRED:-0}" = "1"; then
  : "${DRAFT_MODEL_HOST_PATH:?node env must set DRAFT_MODEL_HOST_PATH}"
  : "${DRAFT_MODEL_TREE_MANIFEST:?node env must set DRAFT_MODEL_TREE_MANIFEST}"
  : "${DRAFT_MODEL_TREE_MANIFEST_SHA256:?node env must set DRAFT_MODEL_TREE_MANIFEST_SHA256}"
  : "${DRAFT_MODEL_CONFIG_JQ_FILTER:?profile must set DRAFT_MODEL_CONFIG_JQ_FILTER}"
  test -f "$DRAFT_MODEL_HOST_PATH/config.json" || { printf 'draft model config missing: %s/config.json\n' "$DRAFT_MODEL_HOST_PATH" >&2; exit 10; }
  jq -e "$DRAFT_MODEL_CONFIG_JQ_FILTER" "$DRAFT_MODEL_HOST_PATH/config.json" >/dev/null || {
    printf 'draft model config does not match profile %s\n' "$PROFILE_ID" >&2
    exit 10
  }
  test -f "$DRAFT_MODEL_TREE_MANIFEST" || { printf 'draft model tree manifest missing: %s\n' "$DRAFT_MODEL_TREE_MANIFEST" >&2; exit 10; }
  [[ "$DRAFT_MODEL_TREE_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] || { printf 'DRAFT_MODEL_TREE_MANIFEST_SHA256 must be 64 lowercase hex characters\n' >&2; exit 10; }
  test "$(sha256sum "$DRAFT_MODEL_TREE_MANIFEST" | awk '{print $1}')" = "$DRAFT_MODEL_TREE_MANIFEST_SHA256" || { printf 'approved draft model tree manifest SHA-256 mismatch\n' >&2; exit 10; }
  "$script_dir/verify-model-tree.sh" "$DRAFT_MODEL_HOST_PATH" "$DRAFT_MODEL_TREE_MANIFEST"
fi

local_image_ref="$IMAGE_REF"
if test -n "${LOCAL_IMAGE_ENV:-}" && test -n "${!LOCAL_IMAGE_ENV:-}"; then
  local_image_ref="${!LOCAL_IMAGE_ENV}"
fi
test "$(docker image inspect "$local_image_ref" --format '{{.Os}}/{{.Architecture}}' 2>/dev/null || true)" = "linux/arm64" || {
  printf 'required linux/arm64 image is not loaded: %s\n' "$local_image_ref" >&2
  exit 11
}
test "$(docker image inspect "$local_image_ref" --format '{{.Id}}')" = "$IMAGE_CONFIG_DIGEST" || {
  printf 'image config digest mismatch: %s\n' "$local_image_ref" >&2
  exit 11
}
docker info >/dev/null
nvidia-smi -L >/dev/null
docker run --rm --network none --gpus all --entrypoint nvidia-smi "$local_image_ref" -L >/dev/null || {
  printf 'container GPU visibility check failed: %s\n' "$local_image_ref" >&2
  exit 11
}

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  printf 'container already exists: %s\n' "$CONTAINER_NAME" >&2
  exit 12
fi

if test -n "${PROFILE_PATCH_ENV:-}"; then
  patch_path="${!PROFILE_PATCH_ENV:-}"
  test -f "$patch_path" || { printf '%s must point to the approved patch\n' "$PROFILE_PATCH_ENV" >&2; exit 13; }
  test "$(sha256sum "$patch_path" | awk '{print $1}')" = "$PROFILE_PATCH_SHA256" || { printf 'profile patch SHA-256 mismatch\n' >&2; exit 13; }
fi

if test -n "${PROFILE_WRAPPER_ENV:-}"; then
  wrapper_path="${!PROFILE_WRAPPER_ENV:-}"
  test -f "$wrapper_path" || { printf '%s must point to the approved wrapper\n' "$PROFILE_WRAPPER_ENV" >&2; exit 14; }
  test "$(sha256sum "$wrapper_path" | awk '{print $1}')" = "$PROFILE_WRAPPER_SHA256" || { printf 'profile wrapper SHA-256 mismatch\n' >&2; exit 14; }
fi

printf 'preflight OK: profile=%s rank=%s fabric=%s peer=%s image=%s model=%s\n' \
  "$PROFILE_ID" "$NODE_RANK" "$THIS_FABRIC_IP" "$PEER_FABRIC_IP" "$local_image_ref" "$MODEL_HOST_PATH"
