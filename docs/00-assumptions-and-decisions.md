# 전제와 결정 기록

기준일: 2026-09-03 KST

## 확인된 전제

- DGX Spark 한 대는 ARM64 Grace CPU, GB10 GPU, 128 GB unified memory를 제공한다.
- 한 장비에 물리 GPU가 하나이므로 두 장비를 가로지르는 `TP=2`는 멀티노드 분산 실행이다.
- 두 모델 계열 모두 한 장비에 들어가지 않는다. 두 장비를 한 모델에 모두 사용하므로 DS4F와 GLM을 동시에 상주시킬 수 없다.
- DGX Spark에는 DGX OS, NVIDIA driver/CUDA 개발 스택, Docker와 NVIDIA Container Toolkit/runtime 연동이 기본 제공된다. 실제 출고 버전은 도착 후 확인한다.
- 직접 연결용 ConnectX-7 QSFP 포트는 Ethernet/RoCE로 사용한다. NVIDIA가 열거한 승인 cable을 별도 조달해야 한다.
- 폐쇄망에서는 registry, Hugging Face, GitHub, apt/pip에 접근하지 않는 것을 정상 조건으로 본다.
- 이 저장소는 외부망의 조사·반입 준비와 내부망의 SSH 기반 설치·운영 하네스를 함께 제공하되, 두 모드를 같은 세션에서 암묵적으로 전환하지 않는다.

## 결정

### D-001: 런타임은 container-first

호스트 driver와 Docker/NVIDIA runtime은 DGX OS 기본 구성을 유지하고, PyTorch·CUDA user-space·vLLM·FlashInfer·모델별 patch는 OCI 이미지 안에 고정한다. ARM64 wheel을 개별 조립하는 방식은 fallback으로만 둔다.

### D-002: 멀티노드 launcher는 vLLM `mp` 우선

현행 vLLM은 `--nnodes`, `--node-rank`, `--master-addr`, `--headless`를 사용하는 멀티노드 multiprocessing을 공식 문서화한다. 2노드 고정 구성에서는 별도 Ray control plane이 없어 반입물과 장애 면적이 작다. NVIDIA의 일반 playbook에 있는 Ray 방식은 fallback이다.

### D-003: 한 번에 한 모델만 활성화

LiteLLM은 안정된 외부 API 주소를 제공하지만 용량을 추가하지 않는다. profile 전환 시 두 vLLM rank를 함께 내리고 새 모델을 worker rank 1부터 시작한다. 두 모델 동시 endpoint를 약속하지 않는다.

### D-004: DS4F는 기본 체크포인트만 운영 범위에 포함

- 1차 운영 baseline은 공식 `deepseek-ai/DeepSeek-V4-Flash-0731`이다.
- NVIDIA DS4F NVFP4는 별도 파일럿 대상이므로 본 프로젝트의 반입 BOM, profile, acceptance에서 제외한다.

### D-005: GLM은 compressed-tensors NVFP4 우선

- 원본 `zai-org/GLM-5.3-Flash` FP8은 약 328.4 GB이므로 제외한다.
- `RedHatAI/GLM-5.3-Flash-NVFP4`는 약 197.9 GB이고 커뮤니티의 2×GB10 TP=2 경로에서 정상 출력 보고가 있어 우선한다.
- `LibertAIDAI/GLM-5.3-Flash-NVFP4`는 파일 처리 단위는 작지만 모델 전체가 별도 대용량 반입 대상이라는 점은 같다. ModelOpt 경로의 손상 token 보고 때문에 운영 후보에서 제외하고 비상 비교용으로만 기록한다.

### D-006: GLM 운영 목표는 DFlash2, non-DFlash2는 검증·rollback

DS4F는 최초 기동에서 speculation을 끄고 기능·품질·32K 이상 decode 안정성을 통과시킨 뒤 DSpark를 켠다. GLM은 `sm121-v8` non-DFlash2로 target model과 top-k patch를 먼저 검증하고, 최종 운영은 `sm121-v11-dflash2` + `incoai` drafter다. DFlash2 장애 시 v8 profile로 rollback한다.

### D-007: immutable pin과 재검역

model revision, OCI platform manifest digest, 외부 근거의 source commit을 동시에 고정한다. 실행 파일·image·model 중 하나라도 바뀌면 같은 이름의 `latest`라 해도 새 아티팩트로 취급하고 해당 반입 경로의 재검토를 수행한다. source commit 고정은 근거 추적용이며 GitHub repository archive를 포털에 제출한다는 뜻이 아니다.

### D-008: eugr를 모델별 image의 공통 launcher로 사용

`eugr/spark-vllm-docker`의 B12X image는 DS4F 0731 전용으로 유지하고 GLM은 tonyd2wild SM121 image를 사용한다. 고정 eugr source의 no-Ray launcher와 custom recipe를 공통 오케스트레이션 계층으로 채택한다. eugr가 자동 주입하는 `--nnodes`, `--node-rank`, `--master-addr`, `--master-port`, `--headless`는 recipe에 중복 기재하지 않는다. 이 저장소의 launcher와 preflight는 독립 검증·rollback 수단으로 유지한다.

### D-009: 모든 모델 snapshot은 검역 포털 밖의 별도 반입 신청

이 프로젝트의 반입 경로 분리 원칙에 따라 모델 snapshot은 크기와 무관하게 조직 승인 반입 포털에 등록하거나 OCI layer에 포함하지 않는다. DS4F target, GLM target, 2.34 GB DFlash2 drafter를 별도 모델 반입 신청 문서에 각각 한 행으로 추가한다. 각 모델의 파일별 source inventory를 증빙으로 붙이고, 승인 후 실제 수령 payload에는 전체 파일 SHA-256 manifest를 새로 생성한다.

### D-010 (2026-09-08 D-015로 반입 경로 대체): 포털 실행물·외부 참고자료·자체 하네스를 분리

- 포털에는 모델 weight/snapshot이 없는 ARM64 runtime OCI image와 폐쇄망 실행에 필수인 개별 파일만 등록한다. 개별 파일에는 최소 eugr launcher 파일, GLM top-k patch와 호스트 PyYAML wheel이 해당하며 각각 원본 URL, commit, SHA-256, license와 SBOM 결과를 가져야 한다.
- GitHub repository 전체 archive는 포털에 등록하지 않는다. eugr, tonyd2wild, NVIDIA playbook, vLLM PR 등의 설명·Dockerfile·운영 참고자료는 실행 payload와 섞지 않고 [외부 repository 참고자료 별도 제출](12-external-repository-reference-submission.md)로 정리해 문서 반입 절차를 따른다.
- 본 저장소에는 폐쇄망에서 외부 repository 없이 재설치·검증·운영할 자체 스크립트, profile, config 예시와 문제 해결 절차를 유지한다. 외부 원문을 그대로 복제한 파일과 자체 작성 파일을 같은 provenance로 표시하지 않는다.

### D-011: SSH 하네스는 내부망 모드에서만 동작

현재 단계는 `external`이며 조사·검역 준비만 수행한다. 승인된 저장소와 payload가 내부망에 있고 두 노드의 SSH 정보가 저장소 밖에서 주입된 뒤에만 `internal`로 전환한다. 하네스는 `check → sync → preflight → worker rank 1 → head rank 0 → LiteLLM → smoke/collect` 순서를 강제하고, 변경 명령은 명시적 `--apply`가 없으면 거부한다. 모드 계약은 [에이전트 실행 모드](13-agent-modes.md)를 따른다.

### D-012: DFlash2 drafter는 비상업적 운영 범위에서 필수 자산

2026-09-03 사용자가 본 운용이 비상업적임을 확인했다. 따라서 `incoai/GLM-5.3-Flash-DFlash2`를 DFlash2 운영 경로의 필수 모델로 확정한다. CC-BY-NC-ND-4.0에 따라 출처 표시와 license 사본을 보존하고 비상업적 용도로만 사용하며, 변경본을 배포하지 않는다. 이 결정은 모델 별도 반입 절차 자체를 면제하지 않는다. `sm121-v8` non-DFlash2 profile은 license 대체 경로가 아니라 DFlash2 기술 장애 시 rollback으로 유지한다.

### D-013: RedHatAI GLM NVFP4의 반입 license는 MIT로 결론

2026-09-03 사용자 결정에 따라 M-02 `RedHatAI/GLM-5.3-Flash-NVFP4@36c184c6cda000a481711306df5adde42f63321a`의 반입 신청 license는 `MIT`로 기재한다. 고정 RedHatAI checkpoint 자체에는 license metadata와 `LICENSE`가 없으므로 선언값(`license_declared`)은 `NOASSERTION`으로 보존하고, 원본 `zai-org/GLM-5.3-Flash`의 MIT license 및 RedHatAI 모델 카드의 원본 provenance를 근거로 내부 판단값(`license_concluded`)을 `MIT`로 기록한다. 이는 RedHatAI uploader가 MIT를 직접 선언했다는 뜻이 아니다. 반입 증빙에는 원본 MIT `LICENSE`와 copyright notice, RedHatAI 모델 카드, 본 결정 기록을 함께 보존하며 새로운 제한 조건이 확인되면 재검토한다.

### D-014 (2026-09-08 D-015로 대체): 15 GB급 runtime OCI는 포털 반입 대상으로 유지

모델 snapshot과 runtime OCI의 반입 경로를 용량만으로 혼동하지 않는다. 100–300 GB급 모델 snapshot 3종은 계속 포털 밖의 별도 모델 반입 대상이다. 모델을 포함하지 않은 14.20 GB GLM DFlash2와 14.18 GB rollback OCI는 포털 대상으로 유지한다. 포털 수집 제한과 완료 여부는 제출 시 검증하되 실제 회차 식별자·시각·상태와 처리 이력은 Git에 남기지 않고 승인된 비공개 기록에서 관리한다.

### D-015: 포털 2회차 + 모델·대형 OCI 수동 반입 (2026-09-08)

사용자 결정에 따라 D-010의 repository 포털 제외와 D-014의 GLM OCI 포털 재신청 방침을 대체한다.

| 구분 | 대상 | 정본 |
|---|---|---|
| 런타임 회차 재생성 | 수집 성공 OCI 2개(eugr B12X, LiteLLM) + RAW R-01~R-06 | `quarantine-oci-successful.txt`, `quarantine-raw-sources.tsv` |
| 소스코드 전용 포털 회차 | 외부 repository E-01~E-07 + 자체 repository S-01, 총 8건 | `quarantine-repository-sources.tsv` |
| 포털 밖 수동 반입 | 모델 M-01~M-03 + 대형 GLM OCI 2개, 총 5건 | `separate-model-import.tsv`, `manual-oci-import.txt` |

최초 회차의 OCI 4 + RAW 6 입력과 실패 기록은 이력으로 보존한다. GLM 실패 항목 때문에 세 번째 포털 회차를 만들지 않는다. 대형 이미지 분류는 위 두 digest의 명시적 결정이며 임의 크기 임계값이 아니다. 저장소 ZIP과 실행 이미지는 별도 유형이다. 외부 원문과 자체 자료는 같은 소스 회차에서도 각각 독립된 provenance를 유지한다. PR/Issue 웹 캡처 W-01~W-05는 보조 조사 근거로 보류하고 이번 최종 수동 목록이나 제3 회차를 만들지 않는다. 원격 PR 토론이 없는 상태는 오프라인 근거의 남은 한계로 기록한다.

### D-016: 회차 재생성과 원본명 보존 (2026-09-08)

D-015의 기존 회차 유지 부분을 대체한다. 사용자의 후속 요청으로 기존 DGX 런타임·코드 회차 및 관리 ID가 이름에 포함된 소스코드 회차를 삭제하고 새로 만든다. 새 런타임 회차는 OCI 2 + RAW 6, 새 소스코드 회차는 repository 8건이다. 수동 모델 3 + 대형 OCI 2는 유지한다. 삭제한 회차의 결과는 이력이며 새 회차의 수집·검사·승인 상태로 재사용하지 않는다.

포털 종속성 이름은 repository의 `owner/repository`, 개별 RAW의 원본 파일명, OCI의 원본 image 이름으로 기재한다. E-01/R-01/S-01 같은 ID는 내부 manifest 대조에만 사용한다. 용도와 유형은 별도 필드에 둔다.

## 미확정·승인 전 질문

| ID | 질문 | 영향 | 해소 방법 |
|---|---|---|---|
| Q-001 | 장비 출고 DGX OS/driver/firmware가 두 대에서 동일한가? | image/driver 호환성 | 도착 즉시 baseline script 실행 |
| Q-002 | 승인된 물리 매체의 허용 종류/용량은? | 약 367.1 GB 모델 payload와 OCI archive의 매체 수 | 보안 담당자에게 허용 매체와 파일시스템 확인 |
| Q-003 | 별도 모델 반입 신청의 정확한 양식, 승인권자, 허용 매체와 포장 단위는 무엇인가? | target 2종과 drafter 1종 반입 | `10-separate-model-import-application.md` 초안을 보안 담당자에게 제출해 확정 |
| Q-004 | 커뮤니티 GHCR/Docker Hub image를 그대로 승인 가능한가? | 재현성과 공급망 | digest/SBOM/scan 결과 제출 또는 내부 ARM64 builder에서 재빌드 |
| Q-006 | API 이용자는 text-only인가, GLM vision도 필요한가? | chat template와 검증 fixture | 요구사항 확정. 기본 가이드는 text/tool 우선 |
| Q-008 | 개별 실행 파일의 포털 결과에서 요구 SBOM·scan·license 증빙이 모두 생성되는가? | eugr launcher와 GLM patch 사용 가능 여부 | 승인 결과를 받으면 개별 URL·SHA와 산출물을 파일별로 대조 |
