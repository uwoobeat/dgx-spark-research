#!/usr/bin/env bash
set -euo pipefail

profile_file="${1:?usage: launch-vllm-tp2.sh PROFILE.sh NODE.env}"
node_env_file="${2:?usage: launch-vllm-tp2.sh PROFILE.sh NODE.env}"

test -f "$profile_file"
test -f "$node_env_file"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/preflight-dgx-node.sh" "$profile_file" "$node_env_file"

# shellcheck source=/dev/null
source "$node_env_file"
# shellcheck source=/dev/null
source "$profile_file"

: "${PROFILE_ID:?profile must set PROFILE_ID}"
: "${CONTAINER_NAME:?profile must set CONTAINER_NAME}"
: "${SERVED_MODEL_NAME:?profile must set SERVED_MODEL_NAME}"
: "${IMAGE_REF:?profile must set IMAGE_REF}"
: "${IMAGE_CONFIG_DIGEST:?profile must set IMAGE_CONFIG_DIGEST}"
: "${API_BIND_HOST:?profile must set API_BIND_HOST}"
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

case "$NODE_RANK" in
  0|1) ;;
  *) echo "NODE_RANK must be 0 or 1" >&2; exit 2 ;;
esac

test -f "$MODEL_HOST_PATH/config.json" || {
  echo "model config missing: $MODEL_HOST_PATH/config.json" >&2
  exit 3
}
test -e /dev/infiniband || {
  echo "/dev/infiniband is missing; verify RDMA before launching" >&2
  exit 4
}

local_image_ref="$IMAGE_REF"
if test -n "${LOCAL_IMAGE_ENV:-}" && test -n "${!LOCAL_IMAGE_ENV:-}"; then
  local_image_ref="${!LOCAL_IMAGE_ENV}"
fi
image_arch="$(docker image inspect "$local_image_ref" --format '{{.Architecture}}' 2>/dev/null || true)"
test "$image_arch" = "arm64" || {
  echo "required ARM64 image is not loaded: $local_image_ref" >&2
  exit 5
}
image_id="$(docker image inspect "$local_image_ref" --format '{{.Id}}')"
test "$image_id" = "$IMAGE_CONFIG_DIGEST" || {
  echo "image config digest mismatch for $local_image_ref" >&2
  echo "expected: $IMAGE_CONFIG_DIGEST" >&2
  echo "actual:   $image_id" >&2
  exit 5
}

cache_host_path="${CACHE_HOST_PATH:-/srv/vllm-cache/$PROFILE_ID}"
mkdir -p "$cache_host_path"

docker_args=(
  run -d
  --name "$CONTAINER_NAME"
  --restart no
  --gpus all
  --network host
  --ipc host
  --shm-size 32g
  --ulimit memlock=-1:-1
  --ulimit stack=67108864:67108864
  --cap-add IPC_LOCK
  --device /dev/infiniband:/dev/infiniband
  -v "$MODEL_HOST_PATH:/model:ro"
  -v "$cache_host_path:/cache"
  -e "VLLM_HOST_IP=$THIS_FABRIC_IP"
  -e "HF_HOME=/cache/huggingface"
  -e "VLLM_CACHE_ROOT=/cache"
  -e "HF_HUB_OFFLINE=1"
  -e "TRANSFORMERS_OFFLINE=1"
  -e "NCCL_NET=IB"
  -e "NCCL_IB_DISABLE=0"
  -e "NCCL_IB_HCA=$RDMA_HCA"
  -e "NCCL_SOCKET_IFNAME=$FABRIC_IFACE"
  -e "GLOO_SOCKET_IFNAME=$FABRIC_IFACE"
  -e "TP_SOCKET_IFNAME=$FABRIC_IFACE"
  -e "NCCL_IB_ADDR_FAMILY=AF_INET"
  -e "NCCL_IB_ROCE_VERSION_NUM=2"
  -e "NCCL_DEBUG=${NCCL_DEBUG_OVERRIDE:-WARN}"
  -e "TORCH_NCCL_ASYNC_ERROR_HANDLING=1"
)

if test -n "${NCCL_IB_GID_INDEX_OVERRIDE:-}"; then
  docker_args+=(-e "NCCL_IB_GID_INDEX=$NCCL_IB_GID_INDEX_OVERRIDE")
fi

for env_pair in "${PROFILE_ENVS[@]:-}"; do
  docker_args+=(-e "$env_pair")
done

if test -n "${PROFILE_PATCH_ENV:-}"; then
  patch_host_path="${!PROFILE_PATCH_ENV:-}"
  test -f "$patch_host_path" || {
    echo "$PROFILE_PATCH_ENV must point to the approved patch file" >&2
    exit 6
  }
  test "$(sha256sum "$patch_host_path" | awk '{print $1}')" = "$PROFILE_PATCH_SHA256" || {
    echo "approved patch SHA-256 mismatch: $patch_host_path" >&2
    exit 6
  }
  docker_args+=(-v "$patch_host_path:$PROFILE_PATCH_TARGET:ro")
fi

if test "${DRAFT_MODEL_REQUIRED:-0}" = "1"; then
  : "${DRAFT_MODEL_HOST_PATH:?node env must set DRAFT_MODEL_HOST_PATH}"
  : "${DRAFT_MODEL_CONTAINER_PATH:?profile must set DRAFT_MODEL_CONTAINER_PATH}"
  docker_args+=(-v "$DRAFT_MODEL_HOST_PATH:$DRAFT_MODEL_CONTAINER_PATH:ro")
fi

command_prefix=(serve)
container_entrypoint="${PROFILE_ENTRYPOINT:-vllm}"
if declare -p PROFILE_COMMAND_PREFIX >/dev/null 2>&1; then
  command_prefix=("${PROFILE_COMMAND_PREFIX[@]}")
fi
if test -n "${PROFILE_WRAPPER_ENV:-}"; then
  wrapper_host_path="${!PROFILE_WRAPPER_ENV:-}"
  test -f "$wrapper_host_path" || {
    echo "$PROFILE_WRAPPER_ENV must point to the approved wrapper" >&2
    exit 7
  }
  test "$(sha256sum "$wrapper_host_path" | awk '{print $1}')" = "$PROFILE_WRAPPER_SHA256" || {
    echo "approved wrapper SHA-256 mismatch: $wrapper_host_path" >&2
    exit 7
  }
  docker_args+=(-v "$wrapper_host_path:/opt/airgap/serve-wrapper.sh:ro")
  container_entrypoint="/bin/bash"
  command_prefix=(/opt/airgap/serve-wrapper.sh)
fi
docker_args+=(--entrypoint "$container_entrypoint")

headless_args=()
if test "$NODE_RANK" = "1"; then
  headless_args=(--headless)
fi

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "container already exists: $CONTAINER_NAME; run stop-vllm-local.sh first" >&2
  exit 8
fi

docker "${docker_args[@]}" "$local_image_ref" \
  "${command_prefix[@]}" /model \
  --served-model-name "$SERVED_MODEL_NAME" \
  --host "$API_BIND_HOST" \
  --port 8000 \
  "${PROFILE_ARGS[@]}" \
  --distributed-executor-backend mp \
  --tensor-parallel-size 2 \
  --pipeline-parallel-size 1 \
  --nnodes 2 \
  --node-rank "$NODE_RANK" \
  --master-addr "$HEAD_FABRIC_IP" \
  --master-port "$MASTER_PORT" \
  "${headless_args[@]}"

printf 'started %s rank=%s profile=%s\n' "$CONTAINER_NAME" "$NODE_RANK" "$PROFILE_ID"
printf 'inspect with: docker logs -f %s\n' "$CONTAINER_NAME"
