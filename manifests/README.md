# Payload manifest 운영

현행 결정: 2026-09-08 D-017. 모든 Docker/OCI와 모델은 수동 반입한다.

- `quarantine-raw-sources.tsv`: 코드·wheel 회차의 6개 원본 URL·이름·commit·bytes·SHA-256.
- `quarantine-repository-sources.tsv`: 소스코드 회차의 외부 7건 + 자체 1건. `name`을 원본 그대로 제출한다.
- `manual-oci-import.txt`: 수동 반입 필수 ARM64 OCI 4개. 실행 이미지를 포털에 등록하지 않는다.
- `manual-oci-conditional.txt`: 미채택 비교 image. 채택 승인 시에도 수동 경로만 사용한다.
- `separate-model-import.tsv`: 수동 모델 3개. 파일별 source inventory는 `models/*.raw.tsv`.
- `artifacts.lock.yaml`: 고정 upstream identity·크기·license와 반입 경로.
- `quarantine-oci-*.txt`: 폐기된 입력. 활성 image 행이 없어야 한다.
- `quarantine-attempt-result.tsv`: 삭제된 최초 회차의 수집 이력과 후속 경로. 현재 승인 상태가 아니다.
- `external-repository-references.tsv`: 외부 source 7건의 provenance 및 오프라인 배치 정본.
- `external-web-references.tsv`: 보조 PR/Issue 조사 근거. 현행 추가 회차·수동 목록에는 포함하지 않는다.

모델·OCI·repository의 실제 수령 SHA-256은 각각 payload 수집 후 계산한다. 목록의 URL 또는 upstream digest만으로 최종 반입 완료를 주장하지 않는다. 모델 라이선스 결론·고지는 `docs/10-separate-model-import-application.md`를 따른다.

실제 회차 식별자·상태·오류는 Git 제외 `state/import-portal-notes.md`에 기록한다. 신청서·SBOM·scan 원본은 `staging/approval/`에 보관한다. 최종 매체에는 `payload-files.sha256`, 모델별 파일 manifest, OCI image identity, 매체별 checksum과 read-back 증빙을 둔다.
