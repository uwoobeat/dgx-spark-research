# 출처 ledger

확인일은 모두 2026-09-03 KST다. GitHub/Hugging Face의 시점 의존 상태는 URL과 commit/revision을 함께 사용한다.

이 ledger는 **조사 근거와 upstream provenance 목록**이며 그 자체가 검역 포털 입력 목록은 아니다. 2026-09-08 결정: 코드·wheel 회차와 repository 소스 전용 회차를 분리한다. 모델 3개와 모든 OCI 4개는 수동 반입한다. repository/tree URL은 고정 source archive 출처이고 PR/issue URL은 보조 조사 근거다.

## NVIDIA DGX Spark

| 출처 | 뒷받침하는 내용 |
|---|---|
| https://docs.nvidia.com/dgx/dgx-spark/release-notes.html | DGX OS/driver/CUDA/kernel/firmware 현재 version |
| https://docs.nvidia.com/dgx/dgx-spark/system-overview.html | Grace Blackwell, ARM64, memory, 10GbE/ConnectX-7 |
| https://docs.nvidia.com/dgx/dgx-spark/nvidia-container-runtime-for-docker.html | Docker/NVIDIA Container Toolkit/runtime 기본 설치·GPU 구성 |
| https://docs.nvidia.com/dgx/dgx-spark/spark-clustering.html | QSFP port, Ethernet/RoCE, interface mapping, approved cable |
| https://docs.nvidia.com/sync/latest/cluster-assistant.html | NVIDIA Sync Cluster Assistant 조건과 cluster 구성 |
| https://docs.nvidia.com/dgx/dgx-spark/enterprise-custom-install.html | USB/local repository 및 air-gapped install |
| https://github.com/NVIDIA/dgx-spark-playbooks/tree/347390338d67262394710802d92b4e48bfc6001c/nvidia/vllm | NVIDIA의 일반 vLLM/Ray 2-node playbook |
| https://packages.ubuntu.com/noble/arm64/jq/filelist | Ubuntu 24.04 ARM64 `jq` binary package 확인; 실제 version은 DGX OS repository baseline으로 고정 |
| https://packages.ubuntu.com/noble/infiniband-diags | Ubuntu ARM64 RDMA 진단 package 참고; DGX vendor OFED package owner를 우선 확인 |

## vLLM

| 출처 | 뒷받침하는 내용 |
|---|---|
| https://docs.vllm.ai/en/stable/serving/parallelism_scaling/ | multi-node Ray와 `mp`, `--nnodes`/rank/headless, RDMA, 동일 model path |
| https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash | DS4F 공식 recipe, DGX Spark 2-node/B12X community image 경로 |
| https://recipes.vllm.ai/zai-org/GLM-5.3-Flash | GLM day-0 runtime, 요구 version과 datacenter recipe |
| https://github.com/vllm-project/vllm/pull/53906 | GLM 5.3 Flash 지원 PR; 기준일 open |
| https://github.com/vllm-project/vllm/pull/53055 | DeepSeek V4 SM121 fallback 수정; 기준일 open |
| https://github.com/vllm-project/vllm/issues/53963 | GLM sparse MLA SM120/121 계열 문제 |
| https://github.com/vllm-project/vllm/issues/54150 | GLM ModelOpt NVFP4 손상 token 비교 |
| https://github.com/vllm-project/vllm/issues/54317 | GLM day-0 image CUDA illegal access 보고 |
| https://github.com/vllm-project/vllm/issues/54413 | GLM hybrid KV offload 문제 |
| https://github.com/vllm-project/vllm/issues/54744 | GLM reasoning/template parameter 불일치 |

## Model cards

| 출처 | 뒷받침하는 내용 |
|---|---|
| https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731 | DS4F 기본 architecture/license/serving |
| https://huggingface.co/zai-org/GLM-5.3-Flash | GLM architecture, MIT license, reasoning parameters; M-02 내부 license 결론의 원본 근거 |
| https://huggingface.co/zai-org/GLM-5.3-Flash/blob/03eb5366286afd40d2221b1d9c63a6dd1ba4832e/LICENSE | M-02 내부 결론에 사용하는 원본 Z.AI MIT license와 copyright notice |
| https://huggingface.co/RedHatAI/GLM-5.3-Flash-NVFP4 | compressed-tensors quantization, official serving example, 원본 provenance와 checkpoint license metadata 미표기 확인 |
| https://huggingface.co/api/models/RedHatAI/GLM-5.3-Flash-NVFP4/revision/36c184c6cda000a481711306df5adde42f63321a | M-02 고정 revision의 card metadata와 파일 목록; license metadata 및 LICENSE 파일 미표기 근거 |
| https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2 | DFlash2 draft architecture, 5-file snapshot, CC-BY-NC-ND-4.0 metadata와 출처 표시·비상업·변경본 배포 제한 의무 |
| https://huggingface.co/LibertAIDAI/GLM-5.3-Flash-NVFP4 | ModelOpt alternative와 known vLLM issues |
| `https://huggingface.co/api/models/<repo>?blobs=true` | pinned revision의 파일 수/크기 계산 |
| pinned revision의 각 `config.json` (`deepseek-ai`, `RedHatAI`, `incoai`) | launcher preflight의 target/drafter model type, architecture, quantization identity 필터; 2026-09-03 직접 재확인 |

## Community primary evidence

| 출처/pin | 용도와 한계 |
|---|---|
| https://github.com/eugr/spark-vllm-docker @ `e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e` | DS4F 기본 B12X TP2 recipe; community |
| https://github.com/local-inference-lab/vllm/tree/b5f995e73e6b7fe27c9927477e277a151ebcc9e9 | eugr B12X fork의 고정 source; 기준 commit에는 GLM 5.3 `glm5next` 구현 없음 |
| https://github.com/eugr/spark-vllm-docker/blob/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/recipes/deepseek-v4-flash-0731.yaml | DS4F 0731 native B12X recipe의 image/backend/env/TP2 설정 |
| https://github.com/eugr/spark-vllm-docker/blob/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/recipes/README.md | custom recipe schema, image override, volume/env, no-Ray와 offline 적용 방식 |
| https://github.com/eugr/spark-vllm-docker/blob/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/launch-cluster.sh | worker-first 실행과 rank/rendezvous/headless 자동 주입, container keepalive 구조 |
| https://raw.githubusercontent.com/eugr/spark-vllm-docker/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/run-recipe.sh | repository archive 대신 개별 검역할 eugr shell wrapper |
| https://raw.githubusercontent.com/eugr/spark-vllm-docker/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/run-recipe.py | repository archive 대신 개별 검역할 eugr recipe parser |
| https://raw.githubusercontent.com/eugr/spark-vllm-docker/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/launch-cluster.sh | repository archive 대신 개별 검역할 no-Ray cluster launcher |
| https://raw.githubusercontent.com/eugr/spark-vllm-docker/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/autodiscover.sh | `launch-cluster.sh`가 source하는 개별 검역 동반 파일 |
| https://raw.githubusercontent.com/eugr/spark-vllm-docker/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/LICENSE | 위 개별 eugr 실행 파일의 MIT license 근거; 포털 실행 RAW가 아니라 외부 repository 참고자료 별도 제출 증빙 |
| https://github.com/eugr/spark-vllm-docker/issues/349 | mutable B12X nightly의 DS4F CUDA graph regression과 rollback 사례 |
| https://github.com/eugr/spark-vllm-docker/issues/358 | DSpark 장시간 acceptance 저하 보고; speculation을 별도 gate로 두는 근거 |
| https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark @ `050081dc41ce6edd4d3f15fa19dc3410ba4210e3` | GLM TP2, image/patch/장애 분석; community이고 upstream 미병합 |
| https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark/issues/14 | 25K–100K 동시 장문 요청의 처리량 붕괴와 `max-num-seqs=1` 완화 근거 |
| https://github.com/elsung/dgx-spark-deepseek-v4-flash | 초기 DS4F TP2 결과; 비교 참고 |
| https://github.com/Weschera/DeepSeek-V4-Flash-0731-DSpark-2x-DGX-Spark | DSpark TP2 community 검증; 성능 수치 재현 필요 |

## LiteLLM과 반입 경로

| 출처 | 뒷받침하는 내용 |
|---|---|
| https://docs.litellm.ai/docs/providers/vllm | `hosted_vllm/` prefix와 proxy `api_base` |
| https://github.com/BerriAI/litellm/releases/tag/v1.99.1 | pinned LiteLLM release |
| https://pypi.org/project/PyYAML/6.0.3/ | eugr host-side recipe parser용 CPython 3.12 ARM64 wheel provenance |
| [반입 포털 공개 체크리스트](08-quarantine-portal.md) | 특정 포털 구현과 무관한 제출 경계와 검증 계약: 모델 없는 ARM64 OCI 4개, 최소 RAW 6개, 명시적 `linux/arm64` 확인, SBOM·license·malware·checksum 증빙 보존 |
| 로컬 비공개 운영 기록 (`state/import-portal-notes.md`, Git 제외) | 실제 포털 주소, 제출 식별자, 확인 시각·상태, 입력 제한과 재시도 이력의 현장 근거. 인증 비밀은 포함하지 않으며 공개 문서의 출처나 반입 payload로 배포하지 않음 |
| 프로젝트 artifact routing 결정 | 2026-09-08 D-015: 포털은 기존 이미지·코드 회차와 repository 소스코드 회차의 두 개다. 모델과 모든 OCI는 수동 반입하며 repository는 수동 목록에서 제외한다. |

## Python ARM64 추가 반입 근거 (2026-09-08)

- [Debian copyright 형식](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/): 파일별·패키징 조건을 구분하고 전체 라이선스를 단순 추정하지 않는 근거. 실제 DEB 40개 copyright 경로·SHA-256·요약은 `manifests/python-deb-license-review.tsv`, 범위와 남은 판정은 [검토 문서](18-python-license-review.md).

- [NVIDIA Spark software stack](https://docs.nvidia.com/dgx/dgx-spark-porting-guide/porting/software-requirements.html): Ubuntu 24.04 기반과 Python 개발 지원. 개별 장비 Python/pip 설치 보장은 아님.
- [Ubuntu noble-updates Python 3.12](https://packages.ubuntu.com/noble-updates/python3.12): ARM64 배포와 minimal·stdlib 의존성 확인.
- [Ubuntu Ports](https://ports.ubuntu.com/ubuntu-ports/): signed noble/noble-updates/noble-security index로 Python/pip Depends·Pre-Depends 40개를 격리 수집. 파일별 버전·source·SHA-256은 `quarantine-python-debs.tsv`. 사용자 미설치 가정에 따른 후보 수집이며 DGX 실기 호환성은 미검증.

## OCI manifest 검증법 (명령)

Registry ref는 다음 명령으로 manifest와 ARM64 config를 직접 확인했다.

```bash
docker buildx imagetools inspect '<REF>' --format '{{json .Manifest}}'
docker buildx imagetools inspect '<REF>' --format '{{json .Image}}'
docker buildx imagetools inspect '<REF>' --raw
```

`artifacts.lock.yaml`의 compressed layer bytes는 raw manifest의 `layers[].size` 합계다. Docker archive 크기는 compression/metadata에 따라 다를 수 있다.
