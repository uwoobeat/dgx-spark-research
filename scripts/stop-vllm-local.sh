#!/usr/bin/env bash
set -euo pipefail

container_name="${1:?usage: stop-vllm-local.sh CONTAINER_NAME}"

if ! docker container inspect "$container_name" >/dev/null 2>&1; then
  printf 'container not present: %s\n' "$container_name"
  exit 0
fi

docker stop --time 120 "$container_name"
docker rm "$container_name"
printf 'stopped and removed local container: %s\n' "$container_name"

