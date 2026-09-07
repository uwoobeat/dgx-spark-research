# Payload manifest 운영

`artifacts.lock.yaml`은 조사 시점의 upstream identity와 크기다. 실제 승인 산출물을 받으면 아래 파일을 별도로 만든다.

검역 포털 입력·현행 범위는 다음과 같다. 모델 snapshot은 크기와 무관하게 모두 제외한다. 전체 GitHub repository archive도 포털에 넣지 않고, 실제 폐쇄망 실행에 필요한 최소 개별 파일만 RAW로 신청한다.

2026-09-07 09:08:20 KST 확인 기준, 필수 OCI 4개와 아래 RAW 6개, 합계 10건은 포털 회차 `3cd1d976-6339-48db-93f6-f0498f7c387f`에서 `DOCKER linux/arm64` + `RAW raw-any`로 수집 중이다. API 응답은 `defaultedTypes=[]`, `status=RUNNING`, `artifactCount=0`이었으며 최종 결과는 [포털 실행 이력](../docs/08-quarantine-portal.md)에 후속 기록한다.

- `quarantine-oci-required.txt`: 최소 운영 OCI image digest 목록
- `quarantine-oci-conditional.txt`: official GLM 비교 image 목록
- `quarantine-raw-sources.tsv`: eugr 실행 파일 4개, GLM top-k patch 1개, ARM64 PyYAML wheel 1개의 고정 URL·bytes·SHA-256 RAW 입력 행

모델 별도 반입 증빙은 다음과 같다.

- `separate-model-import.tsv`: 모델별 별도 반입 신청 한 행 요약
- `models/ds4f-base.raw.tsv`, `models/glm53-redhat-nvfp4.raw.tsv`, `models/glm53-dflash2-draft.raw.tsv`: 세 모델의 파일별 URL·bytes·upstream LFS SHA 목록. 파일명은 source inventory 형식을 뜻하며 포털 RAW 입력물이 아니다.

M-02의 신청서 license 값은 2026-09-03 결정에 따라 MIT다. `artifacts.lock.yaml`은 RedHatAI checkpoint 자체의 미표기 사실을 `license_metadata: not-declared`, `license_declared: NOASSERTION`으로 보존하고, 원본 Z.AI MIT 및 사용자 결정을 적용한 값을 `license_concluded: MIT`로 별도 기록한다.

외부 repository 참고자료 7개는 `external-repository-references.tsv`에서 commit별로 관리하고 별도 문서 반입 절차를 따른다. GitHub PR·Issue 정적 참고자료 5개는 `external-web-references.tsv`에서 별도 관리한다. repository archive와 웹 캡처에는 포털 SBOM 경로를 사용하지 않는다. 실행에 필요한 개별 raw 파일과 전체 repository 참고자료가 겹치는 경우에도 신청 경로와 승인 증빙은 각각 유지한다.

이 파일들은 API payload가 아니며 자동 제출하지 않는다. 포털 OCI/RAW, 모델 별도 신청, 외부 repository 참고자료, 외부 웹 정적 참고자료 제출을 섞지 말고 각각 사람이 검토해 입력한다.

- `payload-files.sha256`: 매체에 넣는 모든 원본/part/archive의 SHA-256
- `oci-images.txt`: `docker image inspect`의 RepoDigest, Id, Architecture
- `models/<id>.files.tsv`: 상대 경로, bytes, SHA-256, 원본 URL
- `media-NN.sha256`: 각 물리 매체의 내용 manifest

검역 시스템이 만든 SBOM/scan/신청 CSV는 수정하지 않고 `staging/approval/` 아래 보관한다. 이 디렉터리는 대용량·민감 산출물이므로 Git에는 넣지 않는다.
