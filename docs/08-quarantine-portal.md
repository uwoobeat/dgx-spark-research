# 반입 포털: 기존 회차와 소스코드 회차

결정일: 2026-09-08. 실제 포털 주소·회차 ID·처리 시각·상세 상태는 Git 제외 `state/import-portal-notes.md`에만 기록한다. 인증 비밀은 `.env`에만 둔다.

## 최종 구성

| 경로 | 범위 | 정본 |
|---|---|---|
| 회차 A — 기존 이미지·코드 | 기존 성공 OCI 2 + RAW 6 유지 | `quarantine-oci-successful.txt`, `quarantine-raw-sources.tsv` |
| 회차 B — 레포지터리 소스코드 | 외부 E-01~E-07 + 자체 S-01, 총 8 | `quarantine-repository-sources.tsv` |
| 포털 밖 수동 | 모델 3 + 대형 GLM OCI 2 | `separate-model-import.tsv`, `manual-oci-import.txt` |

회차 수는 이 프로젝트의 관리 대상 두 개다. 다른 프로젝트의 기존 회차는 변경하지 않는다. 최초 회차의 10개 요청(OCI 4 + RAW 6)은 이력으로 유지하며 GLM OCI 실패 2개는 수동 경로로 전환한다. 실패 기록을 지우거나 세 번째 재시도 회차를 만들지 않는다.

## 회차 A 유지

eugr B12X·LiteLLM의 ARM64 image와 RAW R-01~R-06의 기존 수집 payload를 보존한다. 수집 성공은 보안 승인 완료가 아니며 CVE·license·악성코드 검사와 예외 처분을 항목별로 확인한다. OCI 플랫폼 digest는 `artifacts.lock.yaml`과 일치해야 한다. `quarantine-oci-required.txt`는 최초 요청 4개/전체 runtime identity의 이력이며 새 회차에 그대로 붙여넣는 목록이 아니다.

## 회차 B 생성

1. [소스코드 목록](../manifests/quarantine-repository-sources.tsv)의 8개 행을 대조한다. `repository`는 출처, `pin`은 버전, `download_url`은 고정 commit ZIP이다.
2. 새 소스코드 전용 회차에서 허용된 URL 수집 입력을 사용한다. 실제 UI의 manager 이름·크기 제한·필드는 비공개 운영 기록에 남긴다.
3. 이름·전체 commit·용도·license를 행별로 기재한다. E-03과 S-01의 license 미확정 상태를 임의 MIT로 바꾸지 않는다.
4. 최종 요약이 소스 archive 8건인지 확인한다. OCI·모델·R-01~R-06을 이 회차에 중복 입력하지 않는다.
5. 생성 후 source URL·commit과 수집 archive·파일 수·실제 bytes·SHA-256·license·scan/SBOM 결과를 대조한다. 실제 원격 생성 여부와 처리 상태는 비공개 기록에서 관리한다.

자체 S-01은 공개된 고정 commit만 제출한다. 로컬 미커밋 변경은 해당 원격 archive에 포함되지 않는다. 원문 소스 archive의 검사 결과는 대응 OCI image의 검사 결과를 대체하지 않는다.

## 수동 반입

[수동 다운로드 목록](manual-import-source-links.txt)에 모델 3개와 GLM image 2개만 둔다. 모델은 완전한 snapshot과 파일별 SHA-256, OCI는 load 가능한 archive와 platform digest·archive SHA-256·모델 미포함 검사 증빙을 준비한다. 수동 반입도 조직의 검사·승인·매체 절차를 따른다.

## 제출 결과와 보관

- 기존 회차: `quarantine-attempt-result.tsv`는 원본 결과와 후속 route를 분리한다.
- 소스코드 회차: 생성·수집·검사·승인 단계는 각각 구분하고 실제 결과 없이 완료로 쓰지 않는다.
- 수동 payload: 수령·SHA-256·검사·승인·매체 read-back 결과를 별도로 보존한다.
- 포털이 생성한 신청서·SBOM·scan 원본은 수정하지 않고 `staging/approval/`에 보관한다.
- 공개 문서에는 회차 ID·실계정·조직 식별자를 포함하지 않는다.
