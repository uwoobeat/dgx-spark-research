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
| 포털 실제 양식·처리·문서 확인 | `08-quarantine-portal.md` | OCI 4 + RAW 6 = 10건의 ARM64 회차 `3cd1d976-...` 생성; 2026-09-07 09:08:20 KST 기준 수집 중, 최종 결과 대기 |
| 포털 제출용 OCI/최소 RAW 목록 | `manifests/quarantine-*` | 모델·repository archive 배제 초안 완료; 자동 감사 제공 |
| 모델 별도 반입 목록 | `manifests/separate-model-import.tsv`, `10-separate-model-import-application.md` | target 2개와 DFlash2 drafter의 3개 행 초안 완료, 승인·payload SHA 대기 |
| 외부 repository·웹 참고자료 별도 제출 | `manifests/external-repository-references.tsv`, `manifests/external-web-references.tsv`, `12-external-repository-reference-submission.md` | repository 7개 고정 commit과 PR·Issue 5개 정적 캡처 목록 완료, 조직별 제출 양식 대기 |
| 온라인 수집·checksum·매체 절차 | `05-online-staging.md`, manifest scripts | 완료, 매체 정책 대기 |
| DGX 도착 후 초기 설정·운영 가이드 | `06-airgap-deployment-guide.md`, `07-validation-and-operations.md` | 문서 완료, 실행 대기 |
| rollback·troubleshooting | `07-validation-and-operations.md` | 완료 |

## 완료를 막는 외부 gate

1. 현재 포털 회차 `3cd1d976-6339-48db-93f6-f0498f7c387f`의 10건 수집·SBOM·license·scan·packaging 결과를 대조하고 필수 항목 전체의 승인 가능 상태를 확정해야 한다.
2. 보안 담당자가 포털 밖의 모델 별도 반입 신청과 외부 repository 참고자료 제출 양식·승인권자·검사·포장 방식을 확정해야 한다.
3. 허용 매체가 CD-R, DVD, BD/BDXL 중 무엇인지와 매체당 용량을 확정해야 한다.
4. GLM community wrapper source의 `NOASSERTION`을 검토해야 한다. RedHatAI checkpoint는 자체 license 미표기에 따른 선언값 `NOASSERTION`을 보존하면서 반입 표기를 MIT로 결론냈다. DFlash2 drafter는 비상업적 사용 결정이 완료됐으며 CC-BY-NC-ND-4.0의 출처 표시, license 사본 보존, 비상업적 사용 및 변경본 배포 금지 의무를 반입 증빙에 남긴다.
5. community OCI image 직접 반입 또는 내부 ARM64 재빌드 중 하나를 결정해야 한다.
6. 실제 DGX Spark 2대에서 baseline 일치, RoCE/NCCL, 모델 boot, API, 32K decode, 4시간 soak, rollback을 통과해야 한다.

## 반입 승인 전 최종 순서

1. `manifests/separate-model-import.tsv`의 두 target과 DFlash2 drafter를 별도 모델 반입 문서에 각각 한 행으로 추가하고, M-02의 MIT 내부 결론 증빙과 M-03의 CC-BY-NC-ND-4.0 준수 증빙을 검토한다.
2. 별도 신청이 승인된 뒤 pinned snapshot을 수집하고 모델별 전체 파일 SHA-256 manifest와 그 manifest SHA를 확정한다.
3. 현재 ARM64 회차의 OCI 4개와 RAW 6개 결과를 `manifests/quarantine-*`와 대조하고 각 artifact의 SBOM·scan·license·산출물을 보존한다. 재시도는 새 회차의 target이 명시적 `linux/arm64`인지 먼저 확인한다.
4. eugr 개별 파일 4개, GLM top-k patch, PyYAML wheel의 포털 산출물을 사전 고정 SHA·license와 대조한다.
5. 외부 repository 참고자료의 7개 고정 commit과 외부 웹 정적 참고자료 5개를 별도 문서 반입 목록으로 검토하고, 자체 작성 repository와 분리한다.
6. `audit-import-routing.sh`로 세 모델과 repository archive가 포털 목록에 없고 포털 RAW가 정확히 6개인지 확인한 뒤 2인 검토한다.
7. 포털 scan/license 결과, 별도 모델 승인, 별도 repository·웹 참고자료 승인을 각각 보존한다.
8. 각 경로에서 승인된 payload만 허용 매체에 기록하고 read-back SHA를 검증한다.

## Codex goal 완료 판정

현재는 조사·문서·구성 단계가 완료됐지만 포털 재시도의 최종 결과, 외부 승인과 실장비 acceptance가 남아 있어 goal을 완료로 표시하지 않는다. 위 여섯 외부 gate와 실제 두 모델의 TP=2 서비스 검증이 끝나면 이 표의 `대기` 항목을 실행 결과 링크로 교체하고 완료 처리한다.
