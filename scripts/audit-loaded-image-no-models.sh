#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s IMAGE_REF@sha256:DIGEST EXPECTED_CONFIG_DIGEST\n' "$0" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 64
fi

image_ref="$1"
expected_config_digest="$2"

if [[ ! "$image_ref" =~ @sha256:[0-9a-f]{64}$ ]]; then
  printf 'ERROR: IMAGE_REF must be immutable and end in @sha256:<64 lowercase hex>.\n' >&2
  exit 65
fi

if [[ ! "$expected_config_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  printf 'ERROR: EXPECTED_CONFIG_DIGEST must be sha256:<64 lowercase hex>.\n' >&2
  exit 66
fi

for command_name in docker python3 tar grep sed mktemp wc tr; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'ERROR: required command is unavailable: %s\n' "$command_name" >&2
    exit 69
  fi
done

inspect_fields="$(docker image inspect "$image_ref" \
  --format '{{.Os}} {{.Architecture}} {{.Id}} {{json .Config.Volumes}}')"
read -r image_os image_arch image_id declared_volumes <<<"$inspect_fields"

if [[ "$image_os" != "linux" || "$image_arch" != "arm64" ]]; then
  printf 'ERROR: expected linux/arm64 image, got %s/%s: %s\n' \
    "$image_os" "$image_arch" "$image_ref" >&2
  exit 2
fi

if [[ "$image_id" != "$expected_config_digest" ]]; then
  printf 'ERROR: image config digest mismatch\nexpected: %s\nactual:   %s\n' \
    "$expected_config_digest" "$image_id" >&2
  exit 3
fi

# `docker export` omits mounted volume contents. Refuse an image that declares a
# volume because that would make this final-filesystem inspection incomplete.
if [[ "$declared_volumes" != "null" && "$declared_volumes" != "{}" ]]; then
  printf 'ERROR: image declares volumes; docker export cannot inspect their contents: %s\n' \
    "$declared_volumes" >&2
  exit 4
fi

container_id=""
file_list="$(mktemp)"
hits_file="$(mktemp)"
layer_scan_log="$(mktemp)"
cleanup() {
  if [[ -n "$container_id" ]]; then
    docker rm -f "$container_id" >/dev/null 2>&1 || true
  fi
  rm -f "$file_list" "$hits_file" "$layer_scan_log"
}
trap cleanup EXIT

# Scan every saved layer member before inspecting the merged filesystem. This
# also catches weights copied in an earlier layer and deleted by a later
# whiteout; the bytes would still be present in the OCI/Docker archive.
layer_scan_status=0
docker image save "$image_ref" | python3 /dev/fd/3 3<<'PY' >"$layer_scan_log" || layer_scan_status=$?
import itertools
import re
import sys
import tarfile

pattern = re.compile(
    r"(^|/)(DeepSeek-V4-Flash-0731|GLM-5[.]3-Flash-NVFP4|"
    r"GLM-5[.]3-Flash-DFlash2)(/|$)|"
    r"(^|/)(root|home/[^/]+)/[.]cache/(huggingface/hub/models--|"
    r"modelscope/hub/|torch/hub/checkpoints/)|"
    r"^(models?|weights?|checkpoints?)/|"
    r"[.](safetensors|gguf|ggml|ckpt|onnx|h5|hdf5)$|"
    r"(^|/)(pytorch_model|model)(-[0-9]+-of-[0-9]+)?[.]bin$|"
    r"(^|/)model-[0-9]+-of-[0-9]+[.](pt|pth)$|"
    r"(^|/)consolidated[^/]*[.](pt|pth)$",
    re.IGNORECASE,
)

outer = tarfile.open(fileobj=sys.stdin.buffer, mode="r|*")
layer_count = 0
path_count = 0
hits = []

for outer_member in outer:
    name = outer_member.name.removeprefix("./")
    is_legacy_layer = name.endswith("/layer.tar")
    is_oci_blob = name.startswith("blobs/sha256/")
    if not outer_member.isfile() or not (is_legacy_layer or is_oci_blob):
        continue

    nested_file = outer.extractfile(outer_member)
    if nested_file is None:
        continue
    try:
        nested = tarfile.open(fileobj=nested_file, mode="r|*")
        members = iter(nested)
        first = next(members, None)
    except tarfile.ReadError:
        # In OCI layout, config and manifest JSON are also sha256 blobs.
        continue

    layer_count += 1
    if first is not None:
        members = itertools.chain((first,), members)
    for layer_member in members:
        path_count += 1
        layer_path = layer_member.name.removeprefix("./")
        if pattern.search(layer_path) and len(hits) < 200:
            hits.append(f"{name}\t{layer_path}")

print(f"layer archives scanned: {layer_count}; layer member paths scanned: {path_count}")
if layer_count == 0:
    print("ERROR: no image layer archive was recognized", file=sys.stderr)
    raise SystemExit(7)
if hits:
    print("ERROR: checkpoint/snapshot signatures found in image layer payload", file=sys.stderr)
    print("\n".join(hits))
    raise SystemExit(5)
PY

case "$layer_scan_status" in
  0)
    ;;
  5)
    printf 'ERROR: model checkpoint/snapshot signature found in an image layer: %s\n' \
      "$image_ref" >&2
    sed -n '1,220p' "$layer_scan_log" >&2
    exit 5
    ;;
  *)
    printf 'ERROR: image-layer scan failed with status %s: %s\n' \
      "$layer_scan_status" "$image_ref" >&2
    sed -n '1,220p' "$layer_scan_log" >&2
    exit 6
    ;;
esac

container_id="$(docker create "$image_ref")"

# Stream the merged filesystem without extracting it. With pipefail enabled,
# daemon/export/tar failures abort the audit instead of being mistaken for PASS.
docker export "$container_id" | tar -tf - | LC_ALL=C sed 's#^\./##' >"$file_list"

# This intentionally errs on the side of blocking. DFlash2 implementation files
# such as qwen3_dflash2.py are code and do not match; checkpoint/snapshot paths do.
checkpoint_pattern='(^|/)(DeepSeek-V4-Flash-0731|GLM-5[.]3-Flash-NVFP4|GLM-5[.]3-Flash-DFlash2)(/|$)|(^|/)(root|home/[^/]+)/[.]cache/(huggingface/hub/models--|modelscope/hub/|torch/hub/checkpoints/)|^(models?|weights?|checkpoints?)/|[.](safetensors|gguf|ggml|ckpt|onnx|h5|hdf5)$|(^|/)(pytorch_model|model)(-[0-9]+-of-[0-9]+)?[.]bin$|(^|/)model-[0-9]+-of-[0-9]+[.](pt|pth)$|(^|/)consolidated[^/]*[.](pt|pth)$'

grep_status=0
LC_ALL=C grep -Eai "$checkpoint_pattern" "$file_list" >"$hits_file" || grep_status=$?
case "$grep_status" in
  0)
    printf 'ERROR: model checkpoint/snapshot signature found in image %s\n' "$image_ref" >&2
    sed -n '1,200p' "$hits_file" >&2
    exit 5
    ;;
  1)
    ;;
  *)
    printf 'ERROR: signature scan failed with grep status %s\n' "$grep_status" >&2
    exit 6
    ;;
esac

file_count="$(wc -l <"$file_list" | tr -d '[:space:]')"
sed -n '1p' "$layer_scan_log"
printf 'PASS: immutable linux/arm64 config matched; scanned %s merged-filesystem paths; no checkpoint/snapshot filename signature found in any layer or the merged filesystem: %s\n' \
  "$file_count" "$image_ref"
