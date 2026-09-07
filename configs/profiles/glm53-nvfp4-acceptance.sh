PROFILE_ID="glm53-v8-acceptance"
CONTAINER_NAME="vllm-glm53-v8"
SERVED_MODEL_NAME="glm-5.3-flash"
IMAGE_REF="ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:d77d375c742fc54f436dec5108b440f58f021bc6600052bf0e8fe5840357e78f"
IMAGE_CONFIG_DIGEST="sha256:08e3703a018ecac5150c1c756d92711e10af808a5c2bb9377088ff9db43967f2"
LOCAL_IMAGE_ENV="GLM53_IMAGE_LOCAL_REF"
API_BIND_HOST="127.0.0.1"
MODEL_CONFIG_JQ_FILTER='.model_type == "glm5_next" and ((.architectures // []) | index("Glm5NextForConditionalGeneration") != null) and .quantization_config.quant_method == "compressed-tensors" and .quantization_config.format == "mixed-precision"'
PROFILE_PATCH_ENV="GLM_PATCH_HOST_PATH"
PROFILE_PATCH_TARGET="/usr/local/lib/python3.12/dist-packages/vllm/model_executor/layers/sparse_attn_indexer_kpool.py"
PROFILE_PATCH_SHA256="8a3ecfb0bab2441dd7417ed00a10d142191496149f88e5fe79fcfaea4b160980"
PROFILE_SWAP_POLICY="enabled-swappiness-zero"

PROFILE_ENVS=(
  "VLLM_ENGINE_READY_TIMEOUT_S=3600"
  "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
  "TORCH_CUDA_ARCH_LIST=12.1a"
  "FLASHINFER_CUDA_ARCH_LIST=12.1a"
  "FLASHINFER_DISABLE_VERSION_CHECK=1"
  "NCCL_CUMEM_ENABLE=0"
  "NCCL_NVLS_ENABLE=0"
)

PROFILE_ARGS=(
  --trust-remote-code
  --gpu-memory-utilization 0.85
  --max-model-len 65536
  --max-num-seqs 6
  --block-size 2304
  --moe-backend marlin
  --kv-cache-dtype fp8_e4m3
  --enforce-eager
  --max-num-batched-tokens 8192
  --tool-call-parser glm47
  --enable-auto-tool-choice
  --reasoning-parser glm45
)
