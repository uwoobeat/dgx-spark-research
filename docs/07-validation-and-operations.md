# 검증·운영·장애 대응

이 문서는 승인 자산과 SSH 연결정보를 받은 `internal` 모드에서 사용하는 runbook이다. 현재 `external` 조사·검역 단계에서는 fixture와 명령의 정적 검증까지만 수행하고 아래 실장비 결과를 합격으로 기록하지 않는다.

## 승격 gate

| 단계 | 시험 | 합격 기준 |
|---|---|---|
| A | artifact | 승인된 model tree manifest SHA와 전체 파일 검증, 두 노드 image ID/patch SHA 동일, profile의 model type·architecture·quantization config 일치 |
| B | fabric | peer IP, RDMA device, NCCL log가 기대 NIC 사용 |
| C | boot | 두 rank 유지, head `/health` 200, 외부 다운로드 시도 0 |
| D | API | `/v1/models`, chat, completion, streaming 사용량 정상 |
| E | semantics | Korean/English/code, reasoning 분리, tool call JSON 정상 |
| F | long decode | 32K+ prompt, 100+ decode, CUDA error/손상 token 0 |
| G | stability | 4시간 soak, rank restart/OOM/NCCL timeout 0 |
| H | performance | 동일 fixture에서 baseline 기록, regression threshold 합의 |
| I | speculation | off와 on의 품질 동일성/acceptance/throughput 비교 |
| J | rollback | 15분 이내 직전 검증 profile 복구 |

## smoke test

DGX-1에서 vLLM 직접 endpoint와 LiteLLM endpoint를 각각 시험한다.

```bash
./scripts/smoke-openai-api.sh http://127.0.0.1:8000/v1 ds4f-base
LITELLM_API_KEY="$LITELLM_MASTER_KEY" \
  ./scripts/smoke-openai-api.sh http://127.0.0.1:4000/v1 ds4f-base
```

`finish_reason`, `usage.prompt_tokens`, `usage.completion_tokens`, UTF-8 validity와 JSON parse를 확인한다. streaming 성능은 SSE chunk 수가 아니라 API usage의 completion token 수로 계산한다.

## 모델별 필수 시험

### DS4F

- `reasoning_effort=low/high/max`
- DeepSeek V4 tool-call parser의 schema round trip
- speculation off/on 출력 비교
- JIT compile log가 warmup 후 사라지는지
- 64K에서 시작해 262K, 1M으로 단계 확장

### GLM 5.3 Flash

- Korean과 tool-call payload에서 replacement character(`U+FFFD`)와 반복 token 0
- 32K prompt 뒤 100 token decode로 sparse top-k patch 확인
- `--kv-cache-memory` 없이 profiler 결과와 host `MemAvailable` 기록
- v8 non-DFlash2 기준선 통과 후 v11 DFlash2 k=7로 승격
- GLM target·DFlash2 drafter tree manifest SHA와 top-k patch 파일 SHA가 양 rank에서 일치
- 기본 `max-num-seqs=1`; 25K 이상 동시 장문은 별도 부하 gate
- 공개 TP2 baseline과 동일하게 speculative token `k=7`로 먼저 합격시킨다. 장문 agent workload는 그 뒤 `k=3–4`를 별도 profile로 비교한다.
- eugr cold boot를 3회 반복해 worker-first 직후 head 시작에 따른 rendezvous race가 없는지 확인
- thinking off/on에서 content/reasoning/tool-call semantics를 각각 검증
- vision이 요구되면 image URL 대신 폐쇄망에서 접근 가능한 base64 또는 내부 URL fixture와 `chat_template_mm.jinja` 시험

## 운영 확인

관리 workstation의 중앙 SSH 하네스는 profile별 두 rank 상태와 로그를 함께 확인한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  status configs/profiles/glm53-dflash2-operations.sh
./scripts/cluster-harness.sh configs/cluster.env \
  collect configs/profiles/glm53-dflash2-operations.sh
```

필요할 때 DGX console에서 다음 원시 지표를 교차 확인한다.

```bash
docker ps --filter name=vllm-
docker logs --since 15m <CONTAINER>
nvidia-smi
free -h
ip -s link show <FABRIC_IFACE>
rdma statistic show
```

NCCL 진단 시에만 `NCCL_DEBUG=INFO` 또는 `TRACE`로 재기동한다. 정상 운영 로그에는 `via NET/IB/GDRDMA`가 기대값이고 `via NET/Socket`만 보이면 fabric/NCCL interface를 다시 확인한다. 상세 log에는 내부 주소가 들어갈 수 있으므로 반출 전 별도 검역한다.

## 장애 분류

| 증상 | 우선 확인 | 조치 |
|---|---|---|
| rank 1 대기/timeout | master IP/port, 동일 args, worker-first, firewall | 두 rank 모두 중지 후 network 확인, worker부터 재시작 |
| `NET/Socket` | `NCCL_IB_HCA`, RDMA device mount, GID | 실제 `ibdev2netdev` mapping으로 수정 |
| 모델 load 누락 | snapshot manifest, LFS pointer, path 일치 | 파일 재검증; 인터넷 download 금지 |
| 시작 전 model config 거부 | profile과 `config.json`의 model type/architecture/quantization 불일치 | 경로·revision을 바로잡고 다른 모델에 profile을 재사용하지 않음 |
| GLM 24K 이후 crash | top-k patch SHA/mount, image ID | 두 rank patch 일치 후 baseline profile 재시작 |
| GLM 깨진 UTF-8 | checkpoint quant method/revision | RedHat compressed-tensors인지 확인; ModelOpt 사용 중지 |
| OOM/host freeze | profile별 swap 정책, `MemAvailable`, CUDA graph/speculation | GLM은 active swap+swappiness 0 확인; context/seq 감소, profiler sizing 유지 |
| eugr container는 실행 중이나 API dead | `/health`, `docker top`, 양 rank vLLM process/log | 두 container 모두 중지하고 원인 보존 후 worker→head 재시작 |
| GLM 장문 동시 요청 급락 | active request 수, prompt 길이, DFlash acceptance | `max-num-seqs=1`로 복귀하고 LiteLLM queue 적용 |
| first request NCCL timeout | rank별 JIT compile 시간 차이 | 긴 distributed timeout, 양쪽 cache warmup, 동일 shape warmup |
| reasoning이 content로 누출 | template kwargs/parser version | 최신 model card semantics로 client fixture 재검증 |
| 외부 접속 시도 | offline env, model path가 repo ID인지 | 즉시 중지; local path와 `HF_HUB_OFFLINE=1` 확인 |

## 롤백

1. LiteLLM readiness에서 traffic을 차단한다.
2. DGX-1과 DGX-2의 현재 vLLM container를 모두 중지한다.
3. `docker inspect`와 logs를 보존한다.
4. 이전 profile의 model/image/patch SHA를 manifest와 대조한다.
5. worker rank 1, head rank 0 순서로 이전 profile을 시작한다.
6. smoke/long-decode 최소 gate를 다시 수행하고 LiteLLM traffic을 연다.

image, model, patch를 in-place 수정하지 않는다. 변경판은 새 digest/revision 디렉터리와 새 profile로 만든다.

중앙 SSH 하네스의 native lane에서는 다음처럼 head를 먼저 내리고, 이전 profile을 worker-first로 다시 시작한다. `--apply` 전에는 현재 profile 이름과 두 노드 log 보존 여부를 확인한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  collect configs/profiles/glm53-dflash2-operations.sh state/pre-rollback
# 현재 configs/cluster.env의 CLUSTER_LAUNCHER=eugr로 현 profile 중지
./scripts/cluster-harness.sh configs/cluster.env \
  stop configs/profiles/glm53-dflash2-operations.sh --apply
# 두 rank가 사라진 뒤 CLUSTER_LAUNCHER=native로 바꾸고 local validate 수행
./scripts/cluster-harness.sh configs/cluster.env validate
./scripts/cluster-harness.sh configs/cluster.env \
  preflight configs/profiles/glm53-nvfp4-acceptance.sh
./scripts/cluster-harness.sh configs/cluster.env \
  launch configs/profiles/glm53-nvfp4-acceptance.sh --apply
```

## 운영 기록

각 기동마다 다음을 한 묶음으로 남긴다.

- UTC/KST 시각과 operator
- profile file SHA
- model tree manifest SHA
- image ID/RepoDigest
- host baseline summary
- NIC/HCA/MTU
- vLLM args와 offline env(비밀 제외)
- startup 시간, KV tokens, maximum concurrency
- smoke/long-decode/soak 결과
- rollback target

`collect` 결과는 management IP, hostname과 내부 경로가 포함될 수 있으므로 기본 mode `0600`으로 유지하고 외부 반출 전에 별도 검역·비식별화한다. SSH 개인키, `cluster.env`, node env와 LiteLLM secret은 진단 bundle에 넣지 않는다.

## eugr 정상 경로와 native fail-safe

eugr launcher를 양모델 정상 제어층으로 사용하지만 B12X 단일 image 통합은 아니다. 본 저장소의 중앙 SSH harness/native launcher는 eugr 장애 분석과 독립 acceptance·rollback용이며, 두 경로를 한 기동에서 섞지 않는다.

- DS4F는 고정 B12X image와 offline custom recipe를 사용한다.
- GLM은 `sm121-v11-dflash2`, 승인된 target/drafter와 top-k patch mount를 사용한다.
- eugr는 전체 repository가 아니라 개별 승인된 `run-recipe.sh`, `run-recipe.py`, `launch-cluster.sh`, `autodiscover.sh`만 실행 경로에 둔다. root license와 upstream 설명 자료는 별도 참고자료 문서에 둔다.
- eugr lane은 DGX-1에서 DGX-2로의 passwordless SSH와 out-of-band host key 검증을 추가 gate로 요구한다.
- local image/model만 사용하고 eugr의 download, rebuild, runtime PR/mod fetch는 금지한다.
- eugr가 rank/rendezvous/headless 인자를 자동 주입하므로 recipe에 중복하지 않는다.
- 실행 전 본 저장소 preflight로 image ID, target/drafter tree, patch SHA, NIC/HCA를 양 노드에서 검증한다.
- eugr 경로도 32K decode, 4시간 soak, rollback을 통과해야 한다.
- container keepalive와 vLLM process health를 별도로 감시한다.
- native lane은 management workstation이 DGX-2 worker와 DGX-1 head에 각각 SSH하여 worker-first를 강제한다. eugr 파일이나 node-to-node SSH가 실패할 때만 사용하고 실행 기록에 lane을 남긴다.

최초 acceptance가 실패하면 본 저장소 launcher와 GLM v8 profile로 rollback한다. 상세 근거는 [eugr 양모델 공통화 검토](03a-eugr-dual-model-review.md)에 있다.
