# 폐쇄망 반입 BOM

기준일: 2026-09-03 KST

이 문서는 “무엇을 신청하는가”를 정의한다. 실제 파일별 checksum은 승인된 staging 결과로 [payload manifest](../manifests/README.md)를 채워 확정한다.

## A. 최소 운영 반입안

### OCI images

| 용도 | portal 입력용 immutable ref | arch | 압축 layer 합 | license 판단 | 필수 |
|---|---|---|---:|---|---|
| DS4F 기본 vLLM | `docker.io/eugr/spark-vllm-b12x@sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd` | linux/arm64 | 11.31 GB | wrapper repo MIT; vLLM Apache-2.0 및 image SBOM의 제3자 license 전체 검토 | 예 |
| GLM DFlash2 SM121 vLLM | `ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:4def0ef644cb2e9814136dcffd5e385e21bc594f48f3b292234051904abe85a6` | linux/arm64 | 14.20 GB | source repo root license `NOASSERTION`; vLLM Apache-2.0 기반. wrapper source 판단은 OCI 검역 license review에서 별도 처리하며 drafter license 결정과 무관 | 예 |
| GLM non-DFlash2 rollback | `ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:d77d375c742fc54f436dec5108b440f58f021bc6600052bf0e8fe5840357e78f` | linux/arm64 | 14.18 GB | 최초 기동·DFlash2 기술 장애 rollback용; 동일 wrapper source license review | 예 |
| LiteLLM | `ghcr.io/berriai/litellm@sha256:2d0f10790c6d9a72f240465ebe755987c40bdd0795cba9f57cbebc7ddc6e5c6f` | linux/arm64 | 0.386 GB | 일반 코드 MIT, `enterprise/` 별도 commercial license; basic proxy만 사용하고 SBOM 검토 | 예 |

LiteLLM multiarch index digest가 아닌 ARM64 platform manifest를 의도적으로 사용한다. 모델 weight는 image에 포함되지 않는다.

### Model snapshots

| 용도 | repo@revision | 크기 | license 판단 | 신청 방식 | 필수 |
|---|---|---:|---|---|---|
| DS4F 기본 | `deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062` | 166.899 GB | MIT | 포털 미등록; 별도 모델 반입 문서에 한 행으로 신청 | 예 |
| GLM NVFP4 | `RedHatAI/GLM-5.3-Flash-NVFP4@36c184c6cda000a481711306df5adde42f63321a` | 197.881 GB | MIT(2026-09-03 내부 결론); checkpoint 미표기로 `license_declared=NOASSERTION` | 포털 미등록; 별도 모델 반입 문서에 한 행으로 신청 | 예 |
| GLM DFlash2 drafter | `incoai/GLM-5.3-Flash-DFlash2@bf582e4eacc1810f76656d1811693ff6c6737d2a` | 2.342 GB | CC-BY-NC-ND-4.0; 비상업적 사용 확정 | 포털 미등록; 별도 모델 반입 문서에 한 행으로 신청. 출처·license 사본 보존 및 변경본 배포 금지 | 예 |

Hugging Face snapshot은 safetensors만 받지 않는다. `config*.json`, tokenizer/processor, chat template, remote code, generation config, safetensors index와 license/readme를 포함한 revision 전체가 대상이다.

### 실행 필수 개별 파일과 참고 repository

| 항목 | pin | license | 반입 경로·이유 |
|---|---|---|---|
| eugr 실행 파일 4개 | `e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e`의 `run-recipe.sh`, `run-recipe.py`, `launch-cluster.sh`, `autodiscover.sh` | MIT | 포털 RAW; 폐쇄망 recipe 해석·2노드 기동에 직접 필요 |
| GLM top-k patch | `050081dc41ce6edd4d3f15fa19dc3410ba4210e3`의 `docker/sparse_attn_indexer_kpool_sm121.py`, SHA-256 `8a3ecfb0bab2441dd7417ed00a10d142191496149f88e5fe79fcfaea4b160980` | 파일 header Apache-2.0 | 포털 RAW; 24K+ decode crash 방지 |
| PyYAML ARM64 wheel | `pyyaml-6.0.3-cp312-cp312-manylinux...aarch64.whl`, SHA-256 `9149cad251584d5fb4981be1ecde53a1ca46c891a79788c0df828d2f166bda28` | MIT | 포털 RAW; eugr parser의 외부 `pip` 접속 방지 |
| eugr, B12X vLLM fork, GLM community repo, NVIDIA playbooks, vLLM PR heads | [외부 repository 목록](../manifests/external-repository-references.tsv)의 고정 commit | 항목별 상이 | 포털 제외; 설계·출처·재빌드 참고자료로 별도 문서 반입 |
| 이 저장소 | 반입 시점 공개 commit | 자체 산출물 정책 | 포털·외부 repository 참고자료 묶음과 분리하여 자체 repository로 별도 제출 |

전체 GitHub repository archive는 크기가 작더라도 포털에 신청하지 않는다. 포털 SBOM 비교 단위로 만들지 않고 [외부 repository 참고자료 제출안](12-external-repository-reference-submission.md)에 따라 별도 처리한다. 포털 RAW 6개 행의 URL·bytes·SHA-256은 `manifests/quarantine-raw-sources.tsv`가 정본이다. vLLM/LiteLLM Python dependency는 runtime image 안에 있고, host 측 추가 wheel은 eugr parser용 PyYAML 하나다.

## B. 범위 제외

DS4F NVFP4 checkpoint, Anemll runtime, 관련 playbook은 별도 파일럿 범위이므로 본 신청에서 제외한다. 나중에 파일럿이 승인되면 기존 운영 BOM과 섞지 않고 별도 변경 신청을 만든다.

## C. 조건부/fallback

| 항목 | 조건 |
|---|---|
| `docker.io/vllm/vllm-openai@sha256:905c02933be6021301db2dc284e24e3727467aa3a0f63b41d609885778a07bce` | 커뮤니티 image를 내부 재빌드할 때 official base/provenance가 필요하거나 upstream 비교 시험을 할 때 |
| LibertAIDAI GLM NVFP4 | RedHatAI checkpoint가 runtime/품질 시험에 실패하고 손상 문제를 감수한 비교 진단이 승인될 때만 |
| DGX Spark recovery image/local APT repo | 두 장비 버전이 다르거나 요구 baseline보다 오래됐을 때 |
| ARM64 wheelhouse/build toolchain | 내부 정책상 community image 사용이 금지되어 자체 image 빌드가 필요할 때 |
| 조직 CA/TLS reverse proxy image | 관리망 서비스에 TLS가 필수일 때 |

## D. 별도 반입이 불필요한 기본 항목

정상 DGX Spark에는 DGX OS, NVIDIA driver, CUDA toolkit/developer stack, Docker와 NVIDIA Container Runtime/Toolkit 연동이 있다. 실제 baseline에서 누락된 경우에만 재분류한다. 모델 weight가 없는 runtime image가 user-space CUDA/PyTorch/vLLM/NCCL 관련 runtime을 포함하므로 host에 pip로 다시 설치하지 않는다.

### 조건부 host utility closure

아래 command는 가이드와 스크립트가 직접 사용한다. 출고 image에 있다고 단정하지 않고 `collect-dgx-baseline.sh` 결과로 판정한다.

| 기능/command | Ubuntu package 계열 | 처리 |
|---|---|---|
| `bash` | `bash` | 필수 shell; 없을 가능성은 낮지만 version 기록 |
| `awk`, `sed`, `grep` | `mawk` 또는 `gawk`, `sed`, `grep` | manifest와 report 처리 |
| `find`, `xargs` | `findutils` | payload tree 처리 |
| `sort`, `sha256sum`, `split`, `stat`, `readlink` | `coreutils` | checksum·매체 제약 시 분할·경로 검증 |
| `curl` | `curl` + library dependencies | health/API test |
| `jq` | `jq`, `libjq1`, `libonig5` 계열 | API JSON 검증; 정확한 dependency version은 DGX OS repo로 resolve |
| `ip` | `iproute2` | fabric 주소·route 점검 |
| `ss` | `iproute2` | rendezvous/API port 충돌 점검 |
| `ping` | `iputils-ping` | peer fabric 연결성 사전 점검 |
| `rdma` | `iproute2`/`rdma-core` 설치 상태에서 package owner 확인 | RDMA link/dev 점검 |
| `ibdev2netdev` | DGX OS의 RDMA/OFED package owner 확인 | HCA↔netdev mapping; generic Ubuntu package명으로 추정하지 않음 |
| `systemctl` | `systemd` | 장기 운영 서비스화 |
| `swapon`, `sysctl` | `util-linux`, `procps` | profile별 swap 상태와 GLM `vm.swappiness=0` 확인 |
| `nvidia-smi` | DGX OS NVIDIA driver package | host/container GPU 가시성 확인; 누락 시 개별 패키지보다 recovery 기준선 점검 |

누락 command가 있을 때만 같은 DGX OS release용 local APT repository에서 `linux/arm64` package와 전이 의존성, repository metadata/signing key를 함께 승인 신청한다. 버전은 장비 baseline 전에는 고정할 수 없으므로 이 항목은 조건부다. Docker, NVIDIA Container Toolkit, driver, CUDA, RDMA/OFED stack 자체가 누락되면 일반 utility 몇 개를 설치하는 문제가 아니라 DGX Spark recovery/local repository 절차로 전환한다.

## E. 검역 포털 신청 항목

2026-09-03 인증 후 실제 화면에서 범주와 제출 필드를 재확인했다. 범주는 pip, conda, Maven/Gradle, apt/yum, Docker/Crane OCI, npm 계열, cargo, VS Code, JetBrains, RAW다. 본 프로젝트의 포털 신청은 모델 weight가 없는 OCI 4개와 실행 필수 개별 GitHub raw 파일 5개, PyYAML ARM64 wheel 1개에만 사용한다.

2026-09-07 09:08:20 KST 확인 기준, 이 10건은 포털 회차 `3cd1d976-6339-48db-93f6-f0498f7c387f`에 `DOCKER linux/arm64` + `RAW raw-any`로 생성되어 수집 중이다. API의 `defaultedTypes=[]`를 확인했으므로 Docker target은 기본값이 아니라 명시적 ARM64 선택이다. 생성 직후 artifact 수는 0이며 완료·scan·license·승인 결과는 아직 확정되지 않았다.

- OCI: `image@sha256:digest` 형태로 platform manifest를 지정한다.
- RAW: 외부 URL, 이름, 버전, 목적, license를 기록하며 파일당 5 GB 제한이 있다.
- 시스템은 수집 후 Syft CycloneDX 1.5 SBOM, license check, ClamAV/Trivy scan과 반입승인·유해성점검 문서를 만든다.
- OCI 제출용 목록은 `manifests/quarantine-oci-*.txt`, 개별 실행 파일과 wheel은 `manifests/quarantine-raw-sources.tsv`로 고정한다.
- 실제 화면과 상태·산출물 세부 내용은 [검역 포털 절차](08-quarantine-portal.md)에 기록했다.

DS4F, GLM target, DFlash2 drafter 세 snapshot은 크기와 관계없이 포털에 입력하지 않는다. 세 inventory는 별도 모델 반입 신청 증빙으로만 사용한다. 모델 파일을 RAW 행으로 만들거나 runtime OCI image에 포함하지 않는다. 전체 GitHub repository도 포털 대상이 아니며 별도 참고자료 제출 경로를 따른다.

## F. 용량 계획

- 최소 models: 약 364.8 GB
- DFlash2 drafter: 약 2.34 GB
- 필수 images(rollback 포함): 약 40.1 GB compressed
- source/manifest와 filesystem overhead 포함 1회 반입 예상: **약 410–430 GB**

700 MB CD만 허용하면 600장 이상, 4.7 GB DVD면 95장 안팎, 100 GB BDXL이면 5장 안팎이다. 이는 포맷 overhead와 여분을 포함한 대략치다. 매체 정책을 확정하지 않고 굽기 계획을 확정하면 안 된다.
