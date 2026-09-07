PROFILE_ID="glm53-dflash2"
CONTAINER_NAME="vllm-glm53-dflash2"
SERVED_MODEL_NAME="glm-5.3-flash"
IMAGE_REF="ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:4def0ef644cb2e9814136dcffd5e385e21bc594f48f3b292234051904abe85a6"
IMAGE_CONFIG_DIGEST="sha256:35c6f70ffcba62fd67d7b9d4b4e8300ad177201792ce9cdb1ea18fd449bc23b6"
LOCAL_IMAGE_ENV="GLM53_DFLASH2_IMAGE_LOCAL_REF"
API_BIND_HOST="127.0.0.1"
MODEL_CONFIG_JQ_FILTER='.model_type == "glm5_next" and ((.architectures // []) | index("Glm5NextForConditionalGeneration") != null) and .quantization_config.quant_method == "compressed-tensors" and .quantization_config.format == "mixed-precision"'
PROFILE_PATCH_ENV="GLM_PATCH_HOST_PATH"
PROFILE_PATCH_TARGET="/usr/local/lib/python3.12/dist-packages/vllm/model_executor/layers/sparse_attn_indexer_kpool.py"
PROFILE_PATCH_SHA256="8a3ecfb0bab2441dd7417ed00a10d142191496149f88e5fe79fcfaea4b160980"
PROFILE_SWAP_POLICY="enabled-swappiness-zero"
DRAFT_MODEL_REQUIRED="1"
DRAFT_MODEL_CONFIG_JQ_FILTER='.model_type == "qwen3" and ((.architectures // []) | index("DFlash2DraftModel") != null) and .dflash_config.block_size == 8'
DRAFT_MODEL_CONTAINER_PATH="/models/dflash2-draft"

PROFILE_ENVS=(
  "VLLM_ENGINE_READY_TIMEOUT_S=3600"
  "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
  "TORCH_CUDA_ARCH_LIST=12.1a"
  "FLASHINFER_CUDA_ARCH_LIST=12.1a"
  "FLASHINFER_DISABLE_VERSION_CHECK=1"
  "NCCL_CUMEM_ENABLE=0"
  "NCCL_NVLS_ENABLE=0"
  "NCCL_CROSS_NIC=0"
  "NCCL_IB_MERGE_NICS=0"
)

PROFILE_ARGS=(
  --trust-remote-code
  --gpu-memory-utilization 0.85
  --max-model-len 262144
  --max-num-seqs 1
  --block-size 2304
  --moe-backend marlin
  --speculative-config '{"method":"dflash","model":"/models/dflash2-draft","num_speculative_tokens":7}'
  --kv-cache-dtype fp8_e4m3
  --enforce-eager
  --max-num-batched-tokens 8192
  --tool-call-parser glm47
  --enable-auto-tool-choice
  --reasoning-parser glm45
  --default-chat-template-kwargs '{"enable_thinking":false}'
  --chat-template /model/chat_template_mm.jinja
)
