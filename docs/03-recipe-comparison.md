# vLLM recipe 비교와 권고

기준일: 2026-09-03 KST

## 공통 분산 방식

| 방식 | 장점 | 단점 | 본 프로젝트 판단 |
|---|---|---|---|
| vLLM multi-node `mp` | 공식 CLI, 별도 Ray service 불필요, worker `--headless` | 두 노드 command/환경을 정확히 일치시켜야 함 | **우선** |
| Ray + NVIDIA/vLLM cluster helper | NVIDIA와 vLLM 일반 playbook에 문서화, cluster 관찰 편의 | Ray port·프로세스·이미지 의존성 추가 | fallback |
| 각 커뮤니티 repo wrapper | SM121 patch/JIT warmup 포함 | 외부 shell과 mutable tag에 의존하기 쉬움 | 내용을 고정·검토해 local launcher로 흡수 |

`mp`에서 DGX-1은 rank 0/API server, DGX-2는 rank 1/`--headless`다. 각 장비에 GPU가 하나이므로 `--tensor-parallel-size 2 --pipeline-parallel-size 1 --nnodes 2`로 두 노드 사이 TP를 구성한다. 커뮤니티의 동일 구성 실측이 있지만, vLLM 일반 문서의 대규모 예시는 보통 TP를 노드 내부에 두고 PP를 노드 사이에 두므로 모델별 검증이 필수다.

## DS4F 기본 후보

### vLLM 공식 recipe site

공식 recipe는 0731 checkpoint, DSpark, tool/reasoning parser를 설명하며 DGX Spark 선택 시 2-node TP와 `eugr/spark-vllm-b12x` image를 안내한다. 즉 “공식 recipe 페이지”와 “upstream stock image”를 같은 것으로 보면 안 된다.

### `eugr/spark-vllm-docker`

- source commit: `e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e`
- image: `eugr/spark-vllm-b12x:nightly-20260823`
- ARM64 manifest digest: `sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd`
- compressed layers: 약 11.31 GB
- model recipe: B12X sparse MLA/MoE/linear backend, `instanttensor`, `CUTE_DSL_ARCH=sm_121a`, TP2, DSpark

현재 DS4F 기본의 권고 경로다. mutable `latest`가 아니라 위 platform digest를 반입한다. 제공 script의 다운로드 기능은 폐쇄망에서 사용하지 않고 local model path와 offline environment로 대체한다.

### 기타 커뮤니티 recipe

Anemll, Weschera, elsung, m9e 등의 2×DGX Spark 결과가 있다. 성능 숫자는 prompt, speculation, stream token 계수법과 context가 달라 직접 비교하지 않는다. 여러 결과에서 공통적으로 확인되는 것은 TP2/RoCE, 동일 image, JIT warmup, DSpark의 단계적 활성화다.

## GLM 5.3 Flash 후보

### vLLM 공식 day-0 image/PR

- PR #53906: open, head `8f8cc414d1c7648aad8808ba94e7c7fb1b6a72c2`
- official image candidate: `vllm/vllm-openai:glm53-flash-arm64-cu130`
- ARM64 digest: `sha256:905c02933be6021301db2dc284e24e3727467aa3a0f63b41d609885778a07bce`
- compressed layers: 약 9.71 GB

공식 GLM/vLLM recipe는 TP4급 datacenter Blackwell 예시이며 SM121 sparse MLA path가 없다. 공식 image만 반입해도 DGX Spark에서 실행된다는 보장이 없어 단독 권고하지 않는다.

### `tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark`

- source commit: `050081dc41ce6edd4d3f15fa19dc3410ba4210e3`
- 운영 image `sm121-v11-dflash2`: `sha256:4def0ef644cb2e9814136dcffd5e385e21bc594f48f3b292234051904abe85a6`, ARM64, 약 14.20 GB compressed
- rollback image `sm121-v8`: `sha256:d77d375c742fc54f436dec5108b440f58f021bc6600052bf0e8fe5840357e78f`, ARM64, 약 14.18 GB compressed
- drafter: `incoai/GLM-5.3-Flash-DFlash2@bf582e4eacc1810f76656d1811693ff6c6737d2a`, 2.342 GB, CC-BY-NC-ND-4.0
- required runtime bind patch: `docker/sparse_attn_indexer_kpool_sm121.py`

현재 구체적인 2×DGX Spark TP2 DFlash2 recipe와 장애 분석을 공개한 경로라 운영 목표로 사용한다. 다만 다음 수정 없이 launcher를 그대로 복사하지 않는다.

1. image tag 대신 digest 고정
2. `--kv-cache-memory` 제거, profiler sizing 사용
3. top-k patch와 target/drafter를 두 rank에 동일 경로·SHA로 read-only mount
4. `--block-size 2304`, FP8 KV, TP2 eager mode 유지
5. 기본 `max-num-seqs=1`; 장문 동시 요청은 LiteLLM에서 queue
6. worker 먼저 시작, head 다음 시작
7. drafter의 출처와 CC-BY-NC-ND-4.0 사본을 함께 보존하고 비상업적 용도로만 사용하며 변경본을 배포하지 않음

### 알려진 upstream 위험

| 항목 | 기준일 상태 | 영향 |
|---|---|---|
| vLLM #53963 | open | GLM sparse MLA의 SM120/121 계열 경로 미지원 |
| vLLM #54150 | open | ModelOpt NVFP4 손상 token; compressed-tensors는 비교상 정상 |
| vLLM #54317 | open | day-0 image에서 CUDA illegal memory access 보고 |
| vLLM #54413 | open | hybrid KV offload block layout 문제 |
| vLLM #54744 | open | 구형 `enable_thinking`과 최신 GLM template/parser 불일치 |

## 최종 권고 순서

1. network/NCCL smoke
2. DS4F 기본 + eugr B12X, speculation off
3. DS4F 기본 + DSpark
4. GLM RedHatAI NVFP4 + sm121-v8 + top-k patch, speculation off
5. GLM RedHatAI NVFP4 + sm121-v11 + DFlash2 k=7, max-num-seqs=1
6. DFlash2 32K decode·4시간 soak·모델 전환/rollback

각 단계에서 이전 단계 image/model을 지우지 않는다. 새 profile이 실패하면 두 rank를 중지하고 검증된 profile로 복귀한다.

`eugr/spark-vllm-docker`를 모델별 image의 공통 launcher로 적용하는 방식과 제약은 [eugr 양모델 공통화 검토](03a-eugr-dual-model-review.md)에 둔다. DS4F NVFP4는 별도 파일럿 범위이므로 이 순서와 반입 목록에서 제외한다.
