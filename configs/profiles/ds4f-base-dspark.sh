PROFILE_ID="ds4f-base-dspark"
CONTAINER_NAME="vllm-ds4f-base"
SERVED_MODEL_NAME="ds4f-base"
IMAGE_REF="docker.io/eugr/spark-vllm-b12x@sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd"
IMAGE_CONFIG_DIGEST="sha256:f89e9baedf38ffe3165641d4a937b59b227bbbd58d0116a7518c53b97d601823"
LOCAL_IMAGE_ENV="DS4F_BASE_IMAGE_LOCAL_REF"
API_BIND_HOST="127.0.0.1"
MODEL_CONFIG_JQ_FILTER='.model_type == "deepseek_v4" and ((.architectures // []) | index("DeepseekV4ForCausalLM") != null) and .quantization_config.quant_method == "fp8" and ((.quantization_config.moe_quant_algo // "") != "NVFP4")'
PROFILE_ENTRYPOINT="/opt/nvidia/nvidia_entrypoint.sh"
PROFILE_COMMAND_PREFIX=(vllm serve)

PROFILE_ENVS=(
  "CUTE_DSL_ARCH=sm_121a"
  "VLLM_USE_AOT_COMPILE=1"
  "VLLM_USE_BREAKABLE_CUDAGRAPH=0"
  "VLLM_USE_MEGA_AOT_ARTIFACT=-1"
  "VLLM_MEMORY_PROFILE_INCLUDE_ATTN=1"
  "VLLM_USE_FLASHINFER_SAMPLER=1"
  "VLLM_USE_B12X_WO_PROJECTION=1"
  "VLLM_USE_B12X_MHC=1"
  "VLLM_USE_B12X_FP8_GEMM=1"
  "VLLM_USE_B12X_MOE=1"
  "VLLM_USE_B12X_SPARSE_INDEXER=1"
  "VLLM_USE_V2_MODEL_RUNNER=1"
  "VLLM_MOE_SKIP_PADDING=0"
  "B12X_MLA_SM120_UNIFIED=1"
  "B12X_MOE_FORCE_A8=1"
)

PROFILE_ARGS=(
  --trust-remote-code
  --kv-cache-dtype fp8
  --block-size 256
  --max-model-len 65536
  --max-num-seqs 8
  --max-num-batched-tokens 8192
  --gpu-memory-utilization 0.85
  --enable-prefix-caching
  --tokenizer-mode deepseek_v4
  --tool-call-parser deepseek_v4
  --enable-auto-tool-choice
  --reasoning-parser deepseek_v4
  --reasoning-config '{"reasoning_parser":"deepseek_v4","reasoning_start_str":"","reasoning_end_str":""}'
  --default-chat-template-kwargs.thinking=true
  --default-chat-template-kwargs.reasoning_effort=high
  --load-format instanttensor
  --moe-backend b12x
  --linear-backend b12x
  --attention-backend B12X_MLA_SPARSE
  --max-cudagraph-capture-size 64
  --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"draft_sample_method":"probabilistic","attention_backend":"B12X_MLA_SPARSE"}'
)
