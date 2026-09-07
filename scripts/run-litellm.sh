#!/usr/bin/env bash
set -euo pipefail

config_file="${1:?usage: run-litellm.sh CONFIG.yaml}"
: "${LITELLM_MASTER_KEY:?inject LITELLM_MASTER_KEY from the closed-network secret store}"

test -f "$config_file"
config_abs="$(realpath "$config_file")"
image_ref="ghcr.io/berriai/litellm@sha256:2d0f10790c6d9a72f240465ebe755987c40bdd0795cba9f57cbebc7ddc6e5c6f"
image_config_digest="sha256:69dff3ddc51c4cf4f799d1ddddaca304bf94cfe0f3b357d596de0670baa3b3d1"
local_image_ref="${LITELLM_IMAGE_LOCAL_REF:-$image_ref}"
container_name="litellm-gateway"

image_arch="$(docker image inspect "$local_image_ref" --format '{{.Architecture}}' 2>/dev/null || true)"
test "$image_arch" = "arm64" || {
  echo "required ARM64 LiteLLM image is not loaded under the pinned ref" >&2
  exit 3
}
test "$(docker image inspect "$local_image_ref" --format '{{.Id}}')" = "$image_config_digest" || {
  echo "LiteLLM image config digest mismatch" >&2
  exit 3
}

if docker container inspect "$container_name" >/dev/null 2>&1; then
  echo "container already exists: $container_name" >&2
  exit 4
fi

docker run -d \
  --name "$container_name" \
  --restart no \
  --network host \
  -v "$config_abs:/app/config.yaml:ro" \
  -e LITELLM_MASTER_KEY \
  "$local_image_ref" \
  --config /app/config.yaml \
  --host 0.0.0.0 \
  --port 4000

printf 'started %s on port 4000\n' "$container_name"
