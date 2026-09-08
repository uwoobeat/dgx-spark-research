# 요구사항 완료 감사

기준일: 2026-09-07 KST

## 요구사항별 상태

| 요구사항 | 산출물/증거 | 상태 |
|---|---|---|
| Codex goal과 AGENTS.md | active goal, `AGENTS.md` | 완료 |
| DGX Spark 기본 탑재 항목과 ARM64 기준선 | `01-platform-baseline.md`, baseline script | 문서 완료, 실장비 확인 대기 |
| 모든 필수 Docker image·모델·source 식별 | `04-import-bom.md`, `artifacts.lock.yaml` | 정적 식별 완료 |
| DS4F 기본 검토 | `02-model-compatibility.md`, profiles, model manifest | 운영 후보 확정; NVFP4 파일럿은 범위 제외 |
| GLM 5.3 Flash NVFP4+DFlash2 검토 | `02-model-compatibility.md`, GLM profiles | DFlash2 운영 경로 확정; target은 MIT 내부 결론, drafter는 비상업적 사용 결정 완료 |
| 공식 vLLM/PR/community/별도 repo 비교 | `03-recipe-comparison.md`, source ledger | 완료 |
| eugr에서 두 모델을 함께 운용하는 관점 검토 | `03a-eugr-dual-model-review.md`, custom recipes | 완료; 모델별 image를 사용하는 공통 launcher 채택, 실장비 gate 대기 |
| DGX Spark 2대 TP=2 설정 | launcher, profiles, deployment guide | 정적 완료, NCCL/boot 실증 대기 |
| LiteLLM 설정 | config와 run script | 정적 완료, 실장비 API 시험 대기 |
| 포털 실제 양식·처리·문서 확인 | `08-quarantine-portal.md` | OCI 4 + RAW 6 = 10건의 입력안과 명시적 ARM64 target 검증 절차 완료; 실제 회차 정보는 비공개, 최종 승인 결과 대기 |
| 포털 제출용 OCI/최소 RAW 목록 | `manifests/quarantine-*` | 모델·repository archive 배제 초안 완료; 자동 감사 제공 |
| 현재 회차 부분 수집 후속 분류 | `manifests/quarantine-attempt-result.tsv`, `manifests/quarantine-oci-successful.txt`, `manifests/manual-oci-import.txt`, 비공개 `state/import-portal-notes.md` | 10건 중 8건 수집 성공(OCI 2 + RAW 6), GLM OCI 2건은 `PROTOCOL_ERROR`로 별도 재반입. 성공 OCI 2건의 CVE 이상은 보안 승인 gate로 별도 유지 |
| 모델 별도 반입 목록 | `manifests/separate-model-import.tsv`, `10-separate-model-import-application.md` | target 2개와 DFlash2 drafter의 3개 행 초안 완료, 승인·payload SHA 대기 |
| 외부 repository·웹 참고자료 별도 제출 | `manifests/external-repository-references.tsv`, `manifests/external-web-references.tsv`, `12-external-repository-reference-submission.md` | repository 7개 고정 commit과 PR·Issue 5개 정적 캡처 목록 완료, 조직별 제출 양식 대기 |
| 온라인 수집·checksum·매체 절차 | `05-online-staging.md`, manifest scripts | 완료, 매체 정책 대기 |
| DGX 도착 후 초기 설정·운영 가이드 | `06-airgap-deployment-guide.md`, `07-validation-and-operations.md` | 문서 완료, 실행 대기 |
| rollback·troubleshooting | `07-validation-and-operations.md` | 완료 |

## 완료를 막는 외부 gate

1. 기존 회차에서 수집 성공한 8건의 payload·SBOM·license·scan·packaging 결과를 대조하고, 성공 OCI 2건의 CVE 이상에 대한 조치 또는 예외 승인을 확정해야 한다. 실패한 GLM OCI 2건은 `manual-oci-import.txt`로 수동 반입하여 실제 archive 검사·checksum·승인 결과를 받아야 한다. 실제 회차 식별자와 상세 상태는 비공개 기록에서 관리한다.
2. 보안 담당자가 포털 밖의 모델 별도 반입 신청과 외부 repository 참고자료 제출 양식·승인권자·검사·포장 방식을 확정해야 한다.
3. 허용 매체 종류와 매체당 실사용 용량·파일시스템 제한을 확정해야 한다.
4. GLM community wrapper source의 `NOASSERTION`을 검토해야 한다. RedHatAI checkpoint는 자체 license 미표기에 따른 선언값 `NOASSERTION`을 보존하면서 반입 표기를 MIT로 결론냈다. DFlash2 drafter는 비상업적 사용 결정이 완료됐으며 CC-BY-NC-ND-4.0의 출처 표시, license 사본 보존, 비상업적 사용 및 변경본 배포 금지 의무를 반입 증빙에 남긴다.
5. community OCI image 직접 반입 또는 내부 ARM64 재빌드 중 하나를 결정해야 한다.
6. 실제 DGX Spark 2대에서 baseline 일치, RoCE/NCCL, 모델 boot, API, 32K decode, 4시간 soak, rollback을 통과해야 한다.

## 반입 승인 전 최종 순서

1. `manifests/separate-model-import.tsv`의 두 target과 DFlash2 drafter를 별도 모델 반입 문서에 각각 한 행으로 추가하고, M-02의 MIT 내부 결론 증빙과 M-03의 CC-BY-NC-ND-4.0 준수 증빙을 검토한다.
2. 별도 신청이 승인된 뒤 pinned snapshot을 수집하고 모델별 전체 파일 SHA-256 manifest와 그 manifest SHA를 확정한다.
3. 기존 회차의 성공 OCI 2개·RAW 6개 결과를 각각 `quarantine-oci-successful.txt`와 `quarantine-raw-sources.tsv`에 대조하고 각 artifact의 SBOM·scan·license·산출물을 보존한다. `manual-oci-import.txt`의 실패 GLM OCI 2개는 수동 수집·반입 전후에 target이 명시적 `linux/arm64`인지 확인한다.
4. eugr 개별 파일 4개, GLM top-k patch, PyYAML wheel의 포털 산출물을 사전 고정 SHA·license와 대조한다.
5. 외부 repository 7개와 자체 repository 1개를 소스코드 전용 포털 회차에서 각각 검사·승인한다. 웹 정적 참고자료 5개는 보조 근거로 보류하며 추가 회차·수동 반입 목록에 넣지 않는다.
6. `audit-import-routing.sh`로 세 모델과 repository archive가 포털 목록에 없고 포털 RAW가 정확히 6개인지 확인한 뒤 2인 검토한다.
7. 포털 scan/license 결과, 별도 모델 승인, 별도 repository·웹 참고자료 승인을 각각 보존한다.
8. 각 경로에서 승인된 payload만 허용 매체에 기록하고 read-back SHA를 검증한다.

## Codex goal 완료 판정

현재는 조사·문서·구성 단계가 완료됐지만 포털의 최종 결과, 외부 승인과 실장비 acceptance가 남아 있어 goal을 완료로 표시하지 않는다. 위 여섯 외부 gate와 실제 두 모델의 TP=2 서비스 검증이 끝나면 이 표의 `대기` 항목을 비공개 실행 증빙 참조로 교체하고 완료 처리한다.
