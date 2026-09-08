# DGX Spark 2-node air-gap LLM serving

기준일: **2026-09-07 (KST)**

이 저장소는 서로 이어지는 두 목적을 가진다.

1. 외부망에서 NVIDIA DGX Spark용 근거를 조사하고 immutable 버전·digest·checksum을 고정하여, 코드·wheel 회차, repository 소스코드 회차, 모델·모든 OCI 수동 반입을 서로 섞이지 않게 준비한다.
2. 승인 자산과 SSH 연결정보가 주어진 폐쇄망에서 NVIDIA DGX Spark 2대를 점검·설정하고, vLLM 멀티노드 `mp` executor로 `TP=2` 추론을 worker-first로 실행한 뒤 LiteLLM을 단일 API 게이트웨이로 운영하는 재현 가능한 하네스를 제공한다.

기본 작업 모드는 **`external`(외부망 조사·검역 준비)** 이다. 이 모드에서는 DGX에 SSH 접속하거나 내부망 설치 성공을 가정하지 않는다. 포털은 코드·wheel 회차와 repository 소스코드 전용 회차의 두 개이며 RAW만 입력한다. 모든 OCI는 수동 반입하며 `linux/arm64` manifest를 검증한다. 실제 회차 식별자·시각·상태와 처리 이력은 공개 저장소에 기록하지 않는다. 모드 판정과 전환 gate는 [에이전트 실행 모드 계약](docs/13-agent-modes.md)을 따른다.

## 현재 결론

| 대상 | 권고 체크포인트 | 상태 |
|---|---|---|
| DS4F 기본 | `deepseek-ai/DeepSeek-V4-Flash-0731` | 166.9 GB. 2노드 TP=2 커뮤니티 실측이 가장 많고 vLLM 공식 recipe가 Spark용 커뮤니티 이미지를 지목한다. 1차 운영 후보다. |
| GLM 5.3 Flash | `RedHatAI/GLM-5.3-Flash-NVFP4` + `incoai/GLM-5.3-Flash-DFlash2` | 197.9 GB target + 2.34 GB drafter. `sm121-v11-dflash2`와 필수 top-k patch를 사용하는 운영 후보이며, non-DFlash2 `sm121-v8`은 최초 기동·rollback용이다. |
| LiteLLM | `ghcr.io/berriai/litellm` ARM64 image | vLLM head의 OpenAI-compatible API를 프록시한다. 두 대의 메모리로는 위 모델을 동시에 상주시킬 수 없으므로 한 번에 한 모델만 활성화한다. |

`eugr/spark-vllm-docker`의 고정 commit에서 실행에 필요한 개별 launcher 파일만 checksum과 함께 검역하여 공통 launcher로 사용하되 image는 통합하지 않는다. 전체 GitHub repository archive는 소스코드 전용 포털 회차로 분리한다. DS4F는 eugr B12X image, GLM은 tonyd2wild `sm121-v11-dflash2` image를 각각 사용한다. eugr는 동일 image와 volume을 두 노드에 배치하고 worker rank 1을 먼저 실행한 뒤 head rank 0에 API를 여는 오케스트레이션만 담당한다. 폐쇄망에서는 `--setup`, download/build, runtime PR fetch를 사용하지 않는다.

모델 snapshot은 크기와 관계없이 포털과 OCI image에서 제외한다. DS4F target, GLM target, DFlash2 drafter는 각각 별도 모델 반입 신청 항목이며, 수동 반입 OCI는 모델 weight가 없다는 검사와 SBOM을 통과해야 한다.

2026-09-03 사용자 결정에 따라 `RedHatAI/GLM-5.3-Flash-NVFP4`의 반입 license는 원본 Z.AI MIT를 근거로 `MIT`로 기재한다. 고정 RedHatAI checkpoint 자체의 license metadata와 `LICENSE`는 없으므로 증빙에는 선언값 `NOASSERTION`과 내부 결론값 `MIT`를 분리하고, 원본 MIT license·고지와 모델 카드 provenance를 함께 보존한다.

2026-09-03 사용자가 DFlash2 운용이 비상업적임을 확인했으므로 `incoai` drafter를 DFlash2 운영 경로의 필수 자산으로 확정했다. CC-BY-NC-ND-4.0에 따라 출처와 license 사본을 보존하고 비상업적 용도로만 사용하며 변경본을 배포하지 않는다. `sm121-v8`은 license 대체안이 아니라 기술 rollback이다.

DS4F NVFP4는 별도 파일럿 범위이므로 본 반입·배포안에서 제외했다.

권고 토폴로지는 다음과 같다.

```text
관리망 client -> DGX-1 LiteLLM :4000 -> DGX-1 vLLM :8000
                                      | TP=2 / NCCL over RoCE
                                      +---------------- DGX-2 headless worker
```

두 노드에는 동일한 모델 경로와 동일한 digest의 ARM64 이미지가 있어야 한다. 모델 전환은 기존 TP=2 프로세스를 두 노드에서 종료한 뒤 head에서 다음 eugr recipe를 실행한다. worker(DGX-2) 우선, head(DGX-1) 다음 순서는 eugr가 내부에서 처리한다.

## 반입 자산 경계

| 구분 | 처리 |
|---|---|
| 모델 3종 | 크기와 무관하게 포털/OCI 제외, 별도 모델 반입 신청 |
| 스크립트 5개 + PyYAML wheel 1개 | 코드·wheel 전용 회차 |
| vLLM 3개 + LiteLLM OCI 1개 | 포털 밖 수동 반입, digest·ARM64·실물 검사·SHA-256 확인 |
| 외부 GitHub repository 7개 + 자체 repository 1개 | 고정 commit 소스코드 전용 포털 회차(8건) |
| 이 저장소가 작성한 runbook·script·profile·config | 폐쇄망 SSH 설치·운영 하네스로 유지하며 upstream 참고자료와 provenance를 섞지 않음 |

포털 목록, 모델 신청 목록, 외부 참고자료 문서와 본 저장소 산출물은 서로를 대신하지 않는다. 특히 GitHub repository에 대해 OCI용 SBOM이 생성될 것이라고 가정하지 않는다.

2026-09-08 D-017에 따라 포털은 코드·wheel 6건과 repository 소스 8건의 두 회차다. 모든 실행 OCI 4개와 모델 3개는 수동 반입한다. OCI의 기존 CVE 검토는 유지하며 새 수동 payload의 검증·승인을 별도로 확인한다.

복사·제출용 산출물은 [최종 반입 구성](docs/16-final-import-plan.md), [수동 다운로드 목록](docs/manual-import-source-links.txt), [소스코드 회차 입력 목록](manifests/quarantine-repository-sources.tsv)을 사용한다.

## 공개 및 라이선스 상태

이 저장소 자체의 배포 라이선스는 아직 결정되지 않았다. 루트 `LICENSE`가 추가되기 전에는 자체 작성물에 대한 사용·수정·재배포 허가로 해석하지 않는다. eugr 파생 설정의 MIT 원문과 제3자 경계는 [제3자 고지](THIRD_PARTY_NOTICES.md), 비밀정보와 취약점 보고 절차는 [보안 정책](SECURITY.md)을 따른다.

## 문서 지도

- [전제와 결정](docs/00-assumptions-and-decisions.md)
- [DGX Spark 기준선](docs/01-platform-baseline.md)
- [모델 호환성](docs/02-model-compatibility.md)
- [실행 recipe 비교](docs/03-recipe-comparison.md)
- [eugr 양모델 공통화 검토](docs/03a-eugr-dual-model-review.md)
- [폐쇄망 반입 BOM](docs/04-import-bom.md)
- [온라인 준비와 검역 신청](docs/05-online-staging.md)
- [폐쇄망 배포 가이드](docs/06-airgap-deployment-guide.md)
- [검증·운영·장애 대응](docs/07-validation-and-operations.md)
- [검역 포털 실제 절차](docs/08-quarantine-portal.md)
- [요구사항 완료 감사](docs/09-completion-audit.md)
- [대용량 모델 별도 반입 신청](docs/10-separate-model-import-application.md)
- [OCI 모델 미포함 감사](docs/11-oci-model-content-audit.md)
- [외부 repository 참고자료 별도 제출](docs/12-external-repository-reference-submission.md)
- [에이전트 실행 모드 계약](docs/13-agent-modes.md)
- [SSH 기반 2노드 운영 하네스](docs/14-ssh-harness.md)
- [폐쇄망 로컬 코딩 에이전트 유지보수성](docs/15-local-coding-agent-maintainability.md)
- [출처 ledger](docs/source-ledger.md)

## 내부망 SSH 하네스 시작점

승인 자산과 두 DGX의 연결정보를 받은 뒤 새 세션을 `internal` 모드로 시작한다. 실 IP·사용자명·개인키 경로·API key는 tracked 파일에 넣지 않는다.

```bash
export DGX_AGENT_MODE=internal
mkdir -p state
cp configs/cluster.env.example configs/cluster.env
cp configs/node.env.example state/dgx1.node.env
cp configs/node.env.example state/dgx2.node.env
chmod 600 configs/cluster.env state/dgx1.node.env state/dgx2.node.env
# 검증된 SSH host key를 state/known_hosts에 넣고 mode 600으로 설정
# configs/cluster.env는 CLUSTER_LAUNCHER=eugr, 두 node env는 rank 0/1로 작성
./scripts/cluster-harness.sh configs/cluster.env check
./scripts/cluster-harness.sh configs/cluster.env sync --apply
./scripts/cluster-harness.sh configs/cluster.env preflight configs/profiles/ds4f-base-acceptance.sh
./scripts/cluster-harness.sh configs/cluster.env launch configs/profiles/ds4f-base-acceptance.sh --apply
./scripts/cluster-harness.sh configs/cluster.env smoke configs/profiles/ds4f-base-acceptance.sh
```

`check`, `preflight`, `status` 같은 읽기 중심 단계와 변경 단계가 분리되어 있으며, 변경 명령은 `--apply` 없이는 실행되지 않는다. 실제 순서, 모델 전환, LiteLLM, 로그 수집과 롤백은 [폐쇄망 배포 가이드](docs/06-airgap-deployment-guide.md)와 [검증·운영 가이드](docs/07-validation-and-operations.md)를 따른다.

## 현재 완료 범위와 남은 gate

문서와 manifest의 버전·digest는 기준일 현재 정적으로 확인했다. 실제 DGX Spark 2대가 아직 작업 환경에 없으므로 GPU load, RoCE/NCCL, 장시간 생성 및 품질 테스트는 `검증 전`이다. 다음 항목은 반입 신청 전에 반드시 확정한다.

1. 장비의 실제 DGX OS/driver/firmware 버전과 두 대의 동일성
2. 승인되는 물리 매체 종류와 용량
3. DS4F target, GLM target, DFlash2 drafter 3종을 포털에 등록하지 않는 별도 모델 반입 신청서의 승인과 허용 매체·포장 방식
4. Red Hat 파생 checkpoint의 MIT 내부 결론 증빙과 DFlash2 drafter의 CC-BY-NC-ND-4.0 준수 증빙 보존
5. 커뮤니티 실행 이미지 사용 승인 여부 또는 내부 재빌드 경로
6. 개별 검역할 eugr launcher·GLM patch·PyYAML 파일의 checksum/SBOM과, 소스코드 전용 포털 회차로 제출할 upstream·자체 repository 묶음

조직 승인 반입 포털의 URL과 계정은 `QUARANTINE_*` 변수로 Git에서 제외된 로컬 `.env`에만 저장한다. 이 저장소에는 실제 접속정보가 포함되지 않는다.
