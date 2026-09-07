#!/usr/bin/env bash
set -euo pipefail

base_url="${1:?usage: smoke-openai-api.sh BASE_URL MODEL_NAME}"
model="${2:?usage: smoke-openai-api.sh BASE_URL MODEL_NAME}"

command -v curl >/dev/null
command -v jq >/dev/null

headers=(-H 'Content-Type: application/json')
if test -n "${LITELLM_API_KEY:-}"; then
  headers+=(-H "Authorization: Bearer $LITELLM_API_KEY")
fi

models_tmp="$(mktemp)"
chat_tmp="$(mktemp)"
cleanup() {
  rm -f "$models_tmp" "$chat_tmp"
}
trap cleanup EXIT

curl -fsS --max-time 30 "${headers[@]}" "$base_url/models" -o "$models_tmp"
jq -e --arg model "$model" '.data | any(.id == $model)' "$models_tmp" >/dev/null

request="$(jq -nc --arg model "$model" '{model:$model,messages:[{role:"user",content:"Reply with exactly: AIRGAP_OK"}],temperature:0,max_tokens:32}')"
curl -fsS --max-time 3600 "${headers[@]}" \
  --data "$request" "$base_url/chat/completions" -o "$chat_tmp"

jq -e '
  (.choices | length) == 1 and
  (.choices[0].message.content | type) == "string" and
  (.usage.prompt_tokens | type) == "number" and
  (.usage.completion_tokens | type) == "number"
' "$chat_tmp" >/dev/null

jq '{id, model, finish_reason:.choices[0].finish_reason, content:.choices[0].message.content, usage}' "$chat_tmp"

