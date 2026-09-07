#!/usr/bin/env bash
set -euo pipefail

node_env_file="${1:?usage: run-nccl-smoke.sh NODE.env}"
test -f "$node_env_file"
# shellcheck source=/dev/null
source "$node_env_file"

: "${NODE_RANK:?node env must set NODE_RANK}"
: "${HEAD_FABRIC_IP:?node env must set HEAD_FABRIC_IP}"
: "${THIS_FABRIC_IP:?node env must set THIS_FABRIC_IP}"
: "${PEER_FABRIC_IP:?node env must set PEER_FABRIC_IP}"
: "${FABRIC_CIDR:?node env must set FABRIC_CIDR}"
: "${FABRIC_IFACE:?node env must set FABRIC_IFACE}"
: "${RDMA_HCA:?node env must set RDMA_HCA}"
: "${MASTER_PORT:?node env must set MASTER_PORT}"

case "$NODE_RANK" in
  0|1) ;;
  *) echo "NODE_RANK must be 0 or 1" >&2; exit 2 ;;
esac

test -e /dev/infiniband || { echo "/dev/infiniband is missing" >&2; exit 3; }
ip link show dev "$FABRIC_IFACE" >/dev/null
route="$(ip -4 route get "$PEER_FABRIC_IP")"
grep -Eq "(^| )dev ${FABRIC_IFACE}( |$)" <<<"$route" || { echo "peer route does not use $FABRIC_IFACE" >&2; exit 3; }
ping -I "$FABRIC_IFACE" -c 2 -W 2 "$PEER_FABRIC_IP" >/dev/null || { echo "peer fabric ping failed" >&2; exit 3; }
image_ref="${SMOKE_IMAGE_REF:-${DS4F_BASE_IMAGE_LOCAL_REF:-docker.io/eugr/spark-vllm-b12x@sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd}}"
image_config_digest="sha256:f89e9baedf38ffe3165641d4a937b59b227bbbd58d0116a7518c53b97d601823"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_port="$((MASTER_PORT + 1))"

test "$(docker image inspect "$image_ref" --format '{{.Architecture}}' 2>/dev/null || true)" = arm64 || {
  echo "ARM64 smoke image is not loaded under the pinned ref" >&2
  exit 4
}
test "$(docker image inspect "$image_ref" --format '{{.Id}}')" = "$image_config_digest" || {
  echo "smoke image config digest mismatch" >&2
  exit 4
}

docker run --rm \
  --gpus all \
  --network host \
  --ipc host \
  --ulimit memlock=-1:-1 \
  --cap-add IPC_LOCK \
  --device /dev/infiniband:/dev/infiniband \
  -v "$script_dir/nccl-smoke.py:/opt/airgap/nccl-smoke.py:ro" \
  -e "NCCL_NET=IB" \
  -e "NCCL_IB_DISABLE=0" \
  -e "NCCL_IB_HCA=$RDMA_HCA" \
  -e "NCCL_SOCKET_IFNAME=$FABRIC_IFACE" \
  -e "GLOO_SOCKET_IFNAME=$FABRIC_IFACE" \
  -e "NCCL_IB_ADDR_FAMILY=AF_INET" \
  -e "NCCL_IB_ROCE_VERSION_NUM=2" \
  -e "NCCL_DEBUG=INFO" \
  -e "TORCH_NCCL_ASYNC_ERROR_HANDLING=1" \
  --entrypoint python3 \
  "$image_ref" \
  -m torch.distributed.run \
  --nnodes=2 \
  --nproc-per-node=1 \
  --node-rank="$NODE_RANK" \
  --master-addr="$HEAD_FABRIC_IP" \
  --master-port="$smoke_port" \
  /opt/airgap/nccl-smoke.py
