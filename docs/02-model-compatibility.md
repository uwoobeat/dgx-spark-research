# 모델 호환성

기준일: 2026-09-03 KST. 크기는 Hugging Face API의 `siblings[].size` 합계이며 decimal GB다.

## 고정 후보

| ID | revision | 크기 | 최대 단일 파일 | 5 GB 초과 파일 | license 선언 / 결론 | 판단 |
|---|---|---:|---:|---:|---|---|
| `deepseek-ai/DeepSeek-V4-Flash-0731` | `7872f01b1d1fe23eabc4c98b48bffcef5a386062` | 166.899 GB | 3.693 GB | 0 | MIT | DS4F 운영 baseline |
| `zai-org/GLM-5.3-Flash` | `03eb5366286afd40d2221b1d9c63a6dd1ba4832e` | 328.366 GB | 5.365 GB | 61 | MIT | 2×128 GB에 불가, 반입 제외 |
| `RedHatAI/GLM-5.3-Flash-NVFP4` | `36c184c6cda000a481711306df5adde42f63321a` | 197.881 GB | 20.003 GB | 11 | `NOASSERTION` / MIT(내부 결론, 2026-09-03) | GLM 운영 후보, 별도 반입 |
| `incoai/GLM-5.3-Flash-DFlash2` | `bf582e4eacc1810f76656d1811693ff6c6737d2a` | 2.342 GB | 2.342 GB | 0 | CC-BY-NC-ND-4.0 | GLM DFlash2 운영 필수 drafter, 별도 모델 반입 |
| `LibertAIDAI/GLM-5.3-Flash-NVFP4` | `caca4e6a4ebbd66f159d3d2fc256683fd6e27177` | 194.702 GB | 4.164 GB | 0 | MIT | 손상 출력 보고로 비권고 fallback |

`revision`은 branch 이름 대신 snapshot SHA로 사용한다. 모델 디렉터리 자체의 전체 SHA-256 manifest는 승인된 다운로드를 받은 온라인 staging host에서 생성하며, [artifacts.lock.yaml](../manifests/artifacts.lock.yaml)의 API metadata와 대조한다.

위 표의 운영 대상 모델 3종은 파일 크기와 관계없이 모두 검역 포털과 OCI image에서 제외한다. DS4F target, GLM target, DFlash2 drafter는 별도 모델 반입 신청서의 독립된 행과 payload manifest로 추적한다. `DFlash2`라는 이름의 Python 구현 코드가 runtime image에 있는 것과 2.342 GB draft checkpoint가 image에 들어 있는 것은 다른 사항이며, 후자는 허용하지 않는다.

## DS4F 기본 체크포인트

- 공식 0731 checkpoint는 약 304B parameter metadata, 13B active인 혼합 정밀도 모델이다. routed expert는 FP4 계열이고 나머지는 FP8/BF16 계열이라 단순히 “FP8 304B”로 메모리를 계산하면 틀린다.
- 1M context, custom `encoding_dsv4`, reasoning/tool parser와 포함된 DSpark speculative module을 사용한다.
- 48개 safetensors shard가 모두 5 GB 미만이지만 snapshot 전체가 166.9 GB이므로 정책상 포털이 아닌 대용량 모델 별도 반입 대상이다.
- stock vLLM stable만으로 GB10이 보장되지는 않는다. 공식 vLLM recipe의 Spark 경로도 `eugr/spark-vllm-b12x`를 지목하며 B12X kernel/backend를 사용한다.
- 첫 acceptance는 64K context, speculation off로 하고 기능 통과 후 DSpark를 켠다. 1M context는 별도 장시간 시험이다.

## GLM 5.3 Flash NVFP4

- 원본은 320B total/18B active, multimodal, 34 KDA linear-attention + 11 sparse MLA 계열 layer와 mHC를 사용한다.
- 공개 vLLM 지원 PR #53906은 기준일 현재 open, 36 commits/94 files다. vLLM 공식 recipe는 전용 day-0 Docker image를 안내하지만 DGX Spark SM121 TP=2를 검증한 공식 recipe는 아니다.
- `RedHatAI` checkpoint는 LLM Compressor의 compressed-tensors W4A4이고 vision/embedding/output head 등은 원 정밀도를 유지한다. 약 92 GB 이상의 weight가 rank마다 배치되어 KV/activation 여유가 작다.
- 고정 RedHatAI checkpoint 자체의 license metadata와 `LICENSE`는 미표기다. 반입 문서에는 원본 Z.AI 모델의 MIT와 2026-09-03 사용자 결정을 근거로 `MIT`를 기재하되, 증빙에서는 `license_declared=NOASSERTION`과 `license_concluded=MIT`를 분리하고 원본 MIT 고지와 모델 카드 provenance를 보존한다.
- `LibertAIDAI` ModelOpt W4A16 계열은 파일 반입에는 편하지만 SM121에서 간헐적 invalid UTF-8/반복 token 보고가 있다. 운영 경로에서 제외한다.
- 커뮤니티 TP=2 경로에는 SM121 sparse top-k fallback patch가 필요하다. patch 없이는 약 24K 이후 decode에서 illegal memory access가 보고됐다.
- `--kv-cache-memory`를 고정하면 activation reservation이 사라질 수 있으므로 기본 profile에서는 profiler가 크기를 정하게 한다.
- DFlash2 drafter는 5개 파일, 2.342 GB이며 `DFlash2DraftModel`, block size 8이다. 운영 profile은 k=7, FP8 KV, `--block-size 2304`, `--enforce-eager`를 사용한다.
- 2026-09-03 사용자가 운용 목적이 비상업적임을 확인하여 drafter를 DFlash2 경로의 필수 자산으로 확정했다. CC-BY-NC-ND-4.0에 따라 출처 표시와 license 사본을 보존하고 비상업적 용도로만 사용하며 변경본을 배포하지 않는다. `sm121-v8` non-DFlash2 profile은 license 대체안이 아니라 기술 장애 rollback이다.
- 장문 동시 요청에서 처리량 붕괴 보고가 있으므로 기본 `max-num-seqs=1`로 두고 LiteLLM에서 queue한다. 동시성 확대는 별도 부하 시험 후 허용한다.

## 메모리와 동시 서비스 판단

모델 파일 크기는 runtime memory와 같지 않지만 하한 판단에는 충분하다.

- DS4F 기본: TP2 weight 분할의 단순 평균 약 83.4 GB/rank
- GLM NVFP4: 약 98.9 GB/rank

각 rank에는 container/runtime, CUDA graph, activation, communication buffer, KV cache도 필요하다. 따라서 128 GB 노드에서 두 모델을 동시에 반씩 올릴 여유가 없고, 한 모델씩 TP2로 전환한다. CPU/KV offload는 DeepSeek/GLM의 hybrid MLA layout 관련 미해결 문제가 있어 용량 해법으로 채택하지 않는다.

## acceptance 순서

각 checkpoint는 아래 순서를 따로 통과한다.

1. config/tokenizer/remote code의 offline load
2. 두 rank의 정확한 image/model SHA 일치
3. speculation off, 64K 이하 context에서 text completion
4. reasoning 분리와 `reasoning_effort` 3단계
5. tool call JSON/schema
6. Korean/English/code fixture의 비손상 출력
7. 32K prompt + 100 token 이상 decode(특히 GLM top-k patch 검증)
8. 4시간 soak와 반복 전환
9. speculation on A/B
10. 262K, 1M 등 장문 context는 마지막에 확장
