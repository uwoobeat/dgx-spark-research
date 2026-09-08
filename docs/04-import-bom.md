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
| eugr, B12X vLLM fork, GLM community repo, NVIDIA playbooks, vLLM PR heads | [외부 repository 목록](../manifests/external-repository-references.tsv)의 고정 commit | 항목별 상이 | 소스코드 전용 포털 회차 E-01~E-07 |
| 이 저장소 | 반입 시점 공개 commit | 자체 산출물 정책 | 소스코드 전용 포털 회차 S-01; 외부 자료와 provenance 분리 |

전체 GitHub repository archive는 고정 commit으로 소스코드 전용 회차에 신청한다. [외부 repository 참고자료 제출안](12-external-repository-reference-submission.md)에 따라 별도 처리한다. 포털 RAW 6개 행의 URL·bytes·SHA-256은 `manifests/quarantine-raw-sources.tsv`가 정본이다. vLLM/LiteLLM Python dependency는 runtime image 안에 있고, host 측 추가 wheel은 eugr parser용 PyYAML 하나다.

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

2026-09-08 이후 포털은 기존 OCI·RAW 회차와 별도 repository 소스코드 회차로 나눈다. 대형 GLM OCI는 수동 반입한다. 포털 제품별 manager 이름과 필드 구성은 공개 저장소의 계약으로 고정하지 않고 제출 시 승인된 양식에서 확인한다.

필수 입력은 OCI 4개와 RAW 6개, 합계 10건이다. 제출 화면과 생성 결과 모두에서 `DOCKER linux/arm64` + `RAW raw-any`가 명시적으로 기록됐는지 확인한다. Docker target이 기본 architecture로 대체되지 않았다는 증빙과 최종 수집·scan·license·승인 결과는 Git에서 제외된 비공개 실행 기록에 보존한다.

- OCI: `image@sha256:digest` 형태로 platform manifest를 지정한다.
- RAW: 외부 URL, 이름, 버전, 목적, license를 기록하며 각 파일은 승인된 포털 제한을 충족해야 한다.
- 승인 절차가 만든 SBOM, license, 악성코드·취약점 검사와 반입 문서를 보존한다.
- OCI 제출용 목록은 `manifests/quarantine-oci-*.txt`, 개별 실행 파일과 wheel은 `manifests/quarantine-raw-sources.tsv`로 고정한다.
- 제품별 화면·상태값과 실제 실행 결과는 공개 저장소가 아닌 승인된 비공개 기록에서 관리한다. 공개 절차는 [검역 포털 절차](08-quarantine-portal.md)를 따른다.

DS4F, GLM target, DFlash2 drafter 세 snapshot은 크기와 관계없이 포털에 입력하지 않는다. 세 inventory는 별도 모델 반입 신청 증빙으로만 사용한다. 모델 파일을 RAW 행으로 만들거나 runtime OCI image에 포함하지 않는다. 전체 GitHub repository는 소스코드 전용 포털 회차를 따른다.

### 현행 처리 분류

현재 포털 처리 결과는 최초 신청 정본(OCI 4 + RAW 6)을 변경하지 않고, 수집 결과에 따라 다음처럼 분리한다. 항목별 공개 가능한 결과 분류는 `manifests/quarantine-attempt-result.tsv`와 subset 목록에 두고, 실제 회차 식별자·상세 오류·검사 화면은 현장에서 생성하는 비공개 `state/import-portal-notes.md`에만 둔다.

| 분류 | 대상 | 다음 처리 |
|---|---|---|
| 기존 회차 유지 후보 | eugr B12X OCI, LiteLLM OCI, RAW R-01~R-06 | 성공 payload와 manifest를 그대로 보존·반입 후보로 유지. OCI의 CVE 검토/조치 승인이 끝나기 전에는 최종 반입 완료로 표시하지 않음 |
| 수동 대형 OCI 반입 | GLM `sm121-v11-dflash2` OCI, GLM `sm121-v8` rollback OCI | [수동 OCI 목록](../manifests/manual-oci-import.txt)으로 포털 밖 수동 신청. 동일 digest와 `linux/arm64` target을 재확인하고 모델 미포함 실물 검사를 반복 |
| 별도 모델 신청 | M-01 DS4F base, M-02 GLM NVFP4, M-03 DFlash2 drafter | [모델별 신청서](10-separate-model-import-application.md)와 source inventory로 각각 한 행씩 신청. 포털 OCI/RAW에 섞지 않음 |

수집 성공과 보안·라이선스·악성코드·취약점 승인 완료는 서로 다른 상태다. “그대로 반입”은 성공 payload의 identity와 checksum을 유지한다는 의미이며, 검사 이상이 있는 OCI는 승인된 예외 또는 조치 결과를 받은 뒤에만 매체에 기록한다.

## F. 용량 계획

- 최소 models: 약 364.8 GB
- DFlash2 drafter: 약 2.34 GB
- 필수 images(rollback 포함): 약 40.1 GB compressed
- source/manifest와 filesystem overhead 포함 1회 반입 예상: **약 410–430 GB**

매체 수는 승인된 매체의 실사용 용량으로 계산하며 포맷 overhead와 여분을 포함한다. 매체 종류와 파일시스템 정책을 확정하지 않고 기록 계획을 확정하면 안 된다.
