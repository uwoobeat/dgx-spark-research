# 반입 포털: 코드 회차와 레포지터리 회차

결정일: 2026-09-08 (D-018). 모든 Docker/OCI image는 수동 반입하며 포털 회차에 포함하지 않는다. 실제 회차 ID·처리 상태는 Git 제외 `state/import-portal-notes.md`에 기록한다.

| 경로 | 대상 | 입력 정본 |
|---|---|---|
| 회차 A — 스크립트 코드·wheel | 원본 스크립트 5개 + PyYAML ARM64 wheel 1개 + Python DEB 40개 | `quarantine-raw-sources.tsv`, `quarantine-python-debs.tsv` |
| 회차 B — 레포지터리 소스코드 | 외부 7건 + 자체 1건 | `quarantine-repository-sources.tsv` |
| 수동 반입 | 모델 3개 + 실행 OCI 4개 | `separate-model-import.tsv`, `manual-oci-import.txt` |

이미지가 포함됐던 이전 런타임 회차는 제거하고 코드·패키지 46건으로 새로 생성한다. 원본명 소스코드 회차는 유지한다. 다른 프로젝트 회차는 변경하지 않는다.

## 제출 전

- A에는 RAW 46건만, B에는 repository ZIP 8건만 입력한다. Docker/crane 입력과 image archive URL을 넣지 않는다.
- 스크립트·wheel은 원본 파일명, DEB는 원본 package명, repository는 원본 `owner/repository` 이름을 쓴다. 관리 ID와 `source` 접미어를 종속성 명칭에 붙이지 않는다.
- URL·commit·license·목적은 manifest와 대조한다. 미확정 license를 임의로 바꾸지 않는다.
- 최종 요약과 생성된 회차의 manager가 RAW만인지 확인한다.
- 모델을 RAW 파일로 등록하거나 OCI에 포함하지 않는다.

## 수집 후

각 회차의 수집·검사·승인 결과를 별도로 확인한다. 생성 완료가 수집 성공이나 보안 승인을 의미하지 않는다. archive/파일의 실제 bytes·SHA-256·license·scan/SBOM·신청서 원본을 보존한다. 소스코드 검사는 실행 image 검사를 대신하지 않는다.

`quarantine-oci-*.txt`는 폐기된 입력이며 실행 가능한 행이 없다. 최초 OCI 수집 결과는 `quarantine-attempt-result.tsv`에 이력으로만 남긴다. 모든 OCI는 [수동 다운로드 목록](manual-import-source-links.txt)에 따라 수집하고 ARM64·platform digest·모델 미포함·SBOM/scan·실제 archive SHA-256을 별도로 검증한다.
