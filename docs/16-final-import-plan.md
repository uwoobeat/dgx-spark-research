# 최종 반입 구성

결정일: 2026-09-08 (D-017). 최종 산출물은 코드·wheel 회차, 레포지터리 소스코드 회차, 모델·모든 실행 OCI의 수동 반입 목록이다. 포털 회차에는 Docker 이미지를 넣지 않는다. 원본 종속성 명칭을 보존한다.

| 구분 | 유형·건수 | 다운로드/수집 소스 | 입력 목록 |
|---|---|---|---|
| 회차 A: 스크립트 코드·wheel | 스크립트 5개 + ARM64 PyYAML wheel 1개 | 고정 원본 URL, 포털 RAW 수집 | [RAW 6건](../manifests/quarantine-raw-sources.tsv) |
| 회차 B: 소스코드 전용 | 외부 E-01~E-07 + 자체 S-01, commit ZIP 8개 | GitHub 고정 commit archive URL, 포털에서 수집 | [소스코드 회차 입력](../manifests/quarantine-repository-sources.tsv) |
| 수동 반입 | 모델 snapshot 3개 + ARM64 OCI 4개 | Hugging Face 고정 revision / Docker Hub·GHCR platform digest | [수동 다운로드 목록](manual-import-source-links.txt) |

## 수동 반입 7건

| 항목 | 유형 | 규모 기준 | 받아야 하는 것 |
|---|---|---|---|
| M-01 DS4F 기본 | LLM 모델 snapshot | 166,898,661,074 B | 고정 revision의 74개 파일 전체 |
| M-02 GLM NVFP4 | LLM 모델 snapshot | 197,881,157,135 B | 고정 revision의 21개 파일 전체 |
| M-03 DFlash2 drafter | LLM draft 모델 snapshot | 2,342,460,697 B | 고정 revision의 5개 파일 전체 |
| eugr/spark-vllm-b12x | DS4F 실행 OCI, linux/arm64 | 압축 layer 합계 11,313,467,484 B | 모델 없는 전체 image archive |
| berriai/litellm | API gateway OCI, linux/arm64 | 압축 layer 합계 385,624,109 B | 전체 image archive |
| GLM sm121-v11-dflash2 | 실행 Docker/OCI image, linux/arm64 | 압축 layer 합계 14,204,524,092 B | 모델 없는 전체 image의 load 가능한 archive |
| GLM sm121-v8 | rollback Docker/OCI image, linux/arm64 | 압축 layer 합계 14,180,175,179 B | 모델 없는 전체 image의 load 가능한 archive |

모델 크기와 image layer 크기는 기존 pinned 조사값이며, TAR/매체 실제 크기·SHA-256은 수집 후 측정한다. 모델 파일별 URL은 [모델 신청 목록](../manifests/separate-model-import.tsv)의 source inventory를 따른다. OCI 수집 주소는 [manual-oci-import.txt](../manifests/manual-oci-import.txt)의 registry ref다. GitHub 소스 ZIP이나 registry manifest JSON을 OCI archive 대신 반입하지 않는다.

## 소스코드 회차

[입력 TSV](../manifests/quarantine-repository-sources.tsv)는 이름·유형·출처·전체 commit·ZIP 다운로드 URL·용도·license·수집 후 hash 상태를 포함한다. 자체 S-01은 이 TSV에 기록된 공개 commit이며, 그 이후 수정은 해당 archive에 자동 반영되지 않는다. E-05/E-06은 같은 vLLM 저장소의 서로 다른 commit이므로 합치지 않는다. 자체 작성물과 외부 자료의 provenance는 같은 회차에서도 별도 행으로 보존한다.

최초 회차에서 실패한 GLM 2건은 이력으로 남기되 포털 재시도 회차를 만들지 않는다. `quarantine-oci-retry.txt`는 폐기된 계획 기록이며 현행 수집 입력이 아니다. 모든 `quarantine-oci-*.txt` 입력은 폐기했다. 네 runtime identity는 `manual-oci-import.txt`와 `artifacts.lock.yaml`이 정본이며 최초 수집 결과는 `quarantine-attempt-result.tsv` 이력으로 보존한다.

PR/Issue 정적 웹 캡처 5개는 보조 조사 근거로 보류한다. 이번 최종 수동 목록에 넣거나 별도 회차를 추가하지 않는다. 따라서 원격 토론까지 오프라인으로 보존됐다고 주장하지 않는다.

## 완료 판정

목록 작성, 포털 회차 생성, 수집 성공, 검사·승인, 실제 payload 수령·매체 검증을 구분한다. 기존 성공 OCI에도 CVE 검토가 남아 있다. 실제 회차 ID와 처리 상태는 Git 제외 `state/import-portal-notes.md`에 기록하고, 수동 payload는 별도 승인 및 전체 SHA-256·read-back 결과를 확보한다.
