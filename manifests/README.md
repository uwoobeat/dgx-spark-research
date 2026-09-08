# Payload manifest 운영

`artifacts.lock.yaml`은 조사 시점의 upstream identity와 크기다. 실제 승인 산출물을 받으면 아래 파일을 별도로 만든다.

검역 포털 입력·현행 범위는 다음과 같다. 모델 snapshot은 크기와 무관하게 모두 제외한다. GitHub repository archive는 기존 이미지·코드 회차와 분리된 소스코드 전용 회차로 신청한다.

최초 포털 입력 이력은 OCI 4개와 RAW 6개, 합계 10건이다. 현행 구성은 새 런타임 회차(OCI 2 + RAW 6) 재수집와 소스코드 전용 회차 8건이다. 제출 전후에 `DOCKER linux/arm64` + `RAW raw-any`가 명시적으로 기록되고 Docker architecture가 기본값으로 대체되지 않았는지 확인한다. 실제 회차 식별자·시각·상태와 처리 이력은 Git에서 제외된 비공개 실행 기록에 보존한다.

- `quarantine-oci-required.txt`: 최소 운영 OCI image digest 목록
- `quarantine-oci-conditional.txt`: official GLM 비교 image 목록
- `quarantine-oci-successful.txt`: 삭제된 최초 회차에서 수집 성공했던 OCI 2개의 이력 및 새 런타임 회차 입력 subset. 수집 성공은 CVE 예외 검토 및 최종 승인 완료를 뜻하지 않는다.
- `quarantine-oci-retry.txt`: 폐기된 포털 재시도 계획의 기록(입력 행 없음)
- `manual-oci-import.txt`: 포털 밖 수동 반입 GLM OCI 2개
- `quarantine-repository-sources.tsv`: 소스코드 전용 포털 회차 E-01~E-07 + 자체 S-01의 8개 행
- `quarantine-attempt-result.tsv`: 현재 회차의 10개 입력을 항목별로 대조한 결과·대상 환경·후속 route·실패 사유 요약. 실제 회차 ID와 화면 상세는 포함하지 않는다.
- `quarantine-raw-sources.tsv`: eugr 실행 파일 4개, GLM top-k patch 1개, ARM64 PyYAML wheel 1개의 고정 URL·bytes·SHA-256 RAW 입력 행

모델 별도 반입 증빙은 다음과 같다.

- `separate-model-import.tsv`: 모델별 별도 반입 신청 한 행 요약
- `models/ds4f-base.raw.tsv`, `models/glm53-redhat-nvfp4.raw.tsv`, `models/glm53-dflash2-draft.raw.tsv`: 세 모델의 파일별 URL·bytes·upstream LFS SHA 목록. 파일명은 source inventory 형식을 뜻하며 포털 RAW 입력물이 아니다.

M-02의 신청서 license 값은 2026-09-03 결정에 따라 MIT다. `artifacts.lock.yaml`은 RedHatAI checkpoint 자체의 미표기 사실을 `license_metadata: not-declared`, `license_declared: NOASSERTION`으로 보존하고, 원본 Z.AI MIT 및 사용자 결정을 적용한 값을 `license_concluded: MIT`로 별도 기록한다.

외부 repository 참고자료 7개는 `external-repository-references.tsv`에서 commit별로 관리하고 소스코드 전용 포털 회차를 따른다. GitHub PR·Issue 정적 참고자료 5개는 `external-web-references.tsv`에서 별도 관리한다. repository archive는 실제 source scan/SBOM 결과를 보존하며 OCI SBOM과 구분한다. 웹 캡처는 보조 근거로 보류한다. 실행에 필요한 개별 raw 파일과 전체 repository 참고자료가 겹치는 경우에도 신청 경로와 승인 증빙은 각각 유지한다.

현재 반입 결과의 운영 분류는 다음과 같다. eugr·LiteLLM OCI와 RAW R-01~R-06은 새 런타임 회차에서 원본명으로 재수집하고, GLM OCI 두 개는 `manual-oci-import.txt`로 수동 반입한다. 성공 OCI에도 취약점 검사 결과가 남을 수 있으므로 보안 예외/조치 승인 전에는 “반입 완료”로 표시하지 않는다. 세 모델(M-01~M-03)은 항상 모델별 별도 신청 경로를 사용한다.

이 파일들은 API payload가 아니며 자동 제출하지 않는다. 기존 이미지·코드 회차, 소스코드 전용 회차, 모델·대형 OCI 수동 반입을 섞지 말고 각각 사람이 검토해 입력한다. 실제 회차 식별자와 상세 오류는 비공개 `state/import-portal-notes.md`에만 기록한다.

- `payload-files.sha256`: 매체에 넣는 모든 원본/part/archive의 SHA-256
- `oci-images.txt`: `docker image inspect`의 RepoDigest, Id, Architecture
- `models/<id>.files.tsv`: 상대 경로, bytes, SHA-256, 원본 URL
- `media-NN.sha256`: 각 물리 매체의 내용 manifest

검역 시스템이 만든 SBOM/scan/신청 CSV는 수정하지 않고 `staging/approval/` 아래 보관한다. 이 디렉터리는 대용량·민감 산출물이므로 Git에는 넣지 않는다.
