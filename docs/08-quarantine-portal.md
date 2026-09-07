# quarantine.yethangul.kr 실제 신청 절차

확인일: 2026-09-07 KST

인증된 조직 계정으로 로그인해 입력 화면·처리 이력·API 상태를 확인했다. 2026-09-07 09:08:20 KST 확인 기준, `OCI 4 + RAW 6 = 10건`의 유효한 회차는 `3cd1d976-6339-48db-93f6-f0498f7c387f`이며 수집 중이다. 인증정보는 Git 제외 `.env`에만 있고 이 문서에는 기록하지 않는다.

## 이 프로젝트의 포털 범위

포털에는 다음 두 부류만 등록한다.

1. 모델 weight가 없는 `linux/arm64` runtime OCI image 4개
2. 고정 commit의 실행 필수 GitHub raw 파일 5개와 ARM64 PyYAML wheel 1개

따라서 필수 회차 입력은 합계 10건이다. 조건부 official GLM image는 이 수에 포함하지 않는다.

166.899 GB DS4F, 197.881 GB GLM target, 2.342 GB DFlash2 drafter는 크기와 무관하게 포털에 **등록하지 않는다**. 세 모델의 URL, config/tokenizer, weight shard, 분할 part를 RAW 행으로 만들지 않는다. [모델 별도 반입 신청](10-separate-model-import-application.md)과 `manifests/separate-model-import.tsv`에서 관리한다. 전체 GitHub repository archive도 포털에 등록하지 않고 [별도 참고자료 제출](12-external-repository-reference-submission.md)로 분리한다.

## 실행 이력과 현재 상태

| 회차 ID | 결과·조치 |
|---|---|
| `9bdc3a08-cc49-47e8-8688-c437f7385def` | OCI 4 + RAW 6으로 최초 실행. 8/10 수집 성공, 14.20 GB GLM DFlash2와 14.18 GB GLM rollback OCI가 `crane pull ... timed out after PT10M`으로 실패. 사용자 승인 후 삭제했으며 포털에서 복구할 수 없음. |
| `311d7c79-991d-47d0-bc90-0adc048068cc` | 재시도 중 Docker target이 명시적 추가되지 않아 기본 `linux/amd64`로 저장됨. 오반입 방지를 위해 사용자 승인 후 삭제했으며 포털에서 복구할 수 없음. |
| `cdf233bb-8c10-4569-ba1d-7a941cf2ce70` | 2026-09-03 명시적 ARM64 target으로 생성했던 회차. 2026-09-07 포털 목록에서는 확인되지 않았으며 사용자는 기존 회차가 사라진 상태라고 알렸다. 삭제·부재 원인은 확인되지 않았으므로 임의로 단정하지 않는다. |
| `3cd1d976-6339-48db-93f6-f0498f7c387f` | 2026-09-07 09:08:20 KST 생성한 현재 유효 회차. 회차명 `DGX Spark 2노드 로컬 LLM 서빙 런타임 및 검증자료`, target `DOCKER linux/arm64` + `RAW raw-any`, `defaultedTypes=[]`, OCI 4 + RAW 6. 생성 직후 `status=RUNNING`, `artifactCount=0`. |

사용자가 수집 timeout을 10분에서 20분으로 패치했음을 알렸고, 약 15 GB급의 **모델 미포함 runtime OCI**는 포털 범위에 유지하도록 승인했다. 이 변경은 사용자 제공 운영 사실이며, 2026-09-07 생성 회차의 최종 성공·scan·license·승인은 아직 확정되지 않았다. 100–300 GB급 모델 snapshot을 포털에 등록하지 않는 규칙은 변경되지 않았다.

## 신규 회차 입력

### 공통

- `회차명`: 비우면 날짜 기반 자동 이름 사용
- manager: pip, conda, maven, gradle, apt, yum, docker, crane, npm, yarn, pnpm, cargo, VS Code 확장, JetBrains 플러그인, 직접 업로드(RAW)
- `반입 목적`: 최상위 패키지에 적용되고 하위 종속성에 자동 상속
- 여러 manager와 여러 입력을 한 회차에 함께 담을 수 있음
- 마지막 동작은 `반입 데이터 생성`; 신규·재시도 회차는 target과 입력 검토 및 사람 승인 전에 실행 금지

### Docker/Crane

- target OS에서 `Linux`, arch에서 `arm64`를 선택한다.
- 입력은 고정 `docker pull` 또는 `crane pull` 접두어 뒤의 image 목록이다.
- 화면 안내는 `image[:tag]`지만 client parser는 `registry/repo@sha256:<platform-manifest>`도 한 항목으로 인식했다.
- 현재 회차 `3cd1d976-6339-48db-93f6-f0498f7c387f`에서 `DOCKER linux/arm64`가 target 목록에 명시적으로 존재하고 `defaultedTypes=[]`인 것을 API로 확인했다. arch 선택만 한 뒤 `docker 대상 추가`를 누르지 않으면 기본 `linux/amd64`로 저장될 수 있으므로, 회차 생성 전 target 목록을 별도로 확인한다.

### RAW

화면 설명은 “검역 노드가 받아올 수 있는 URL”이며 파일당 5 GB 상한이다. 이 프로젝트에서는 `manifests/quarantine-raw-sources.tsv`의 실행 필수 파일과 wheel에만 사용한다.

| 필드 | 처리 |
|---|---|
| URL | 필수, 검역 노드에서 접근 가능한 HTTPS 원본 |
| 이름 | 필수 |
| 버전 | 선택 |
| 용도 | 필수 |
| 라이선스 | 선택, 공란은 `UNKNOWN` |

`manifests/models/*.raw.tsv`는 이름과 달리 포털 RAW 행이 아니라 세 모델의 source inventory다. 어떠한 행도 포털에 복사하지 않는다. repository archive URL도 RAW로 입력하지 않는다.

## 서버 처리 단계

완료 회차에서 다음 6단계를 확인했다.

1. 해석 — 의존성 관계 해석
2. 수집 — 원본 아티팩트 수집
3. SBOM — Syft → CycloneDX
4. 라이선스 — 라이선스 점검
5. 검역 스캔 — ClamAV · Trivy
6. 문서·산출물 — 문서 생성·패키징

완료 후 SBOM, license, scan, packaging 단계만 개별 재실행할 수 있다. 해석·수집 재실행 버튼은 비활성이고 전체 회차를 다시 만들어야 한다. 재실행은 기존 산출물을 바꿀 수 있으므로 운영 절차에서 별도 변경 승인을 받는다.

## 결과와 문서

완료 회차는 manager별 target, artifact 수, 전체 bytes, license, CVE 수, 검역 판정과 반입 상태를 보여준다. 반입 상태 선택지는 `대기`, `반입 완료`, `반려`, `기존 반입`이다. Docker image도 개별 artifact로 표시되고 SBOM/CVE 결과가 연결된다. RAW 항목은 파일 단위 artifact로 표시된다.

생성되는 문서는 다음 두 가지다.

- `반입승인신청서`: 번호, 반입일자, 반입 부서, SW명, 버전, 배포일자, 출처, 라이선스 정책, 주요기능, 반입목적, 담당자, 검증결과, 배포범위
- `유해성점검신청서`: 번호, 요청부서, SW명, 버전, 배포일자, 출처, 라이선스 정책, 주요기능, 반입목적, 담당자, 원본 해시값

두 문서의 행 번호 일치 여부가 화면에서 검사된다. 문서와 산출물 ZIP, CycloneDX JSON, scan 결과를 승인 기록과 함께 보존한다. 별도 모델 반입 문서에는 모델마다 독립된 행을 두고 동일한 model ID/revision을 사용한다.

## 권고 포털 회차 분리

| 회차 | manager | 내용 | 제출 조건 |
|---|---|---|---|
| 1. 필수 runtime | Docker 또는 Crane | DS4F B12X, GLM DFlash2, GLM v8 rollback, LiteLLM | ARM64 target, community image 승인 |
| 2. 실행 필수 파일 | RAW | eugr 실행 파일 4개, GLM top-k patch, PyYAML ARM64 wheel | 개별 commit/SHA/license 확인 |
| 3. 조건부 image | Docker 또는 Crane | official GLM day-0 | 재빌드 또는 upstream 비교 때만 |

세 모델 반입과 전체 외부 repository 참고자료 제출은 이 회차들과 별개다. 개별 raw 파일이나 조건부 image 문제가 필수 runtime 승인을 불필요하게 막지 않도록 회차 분리를 권고한다. 현재 회차는 사용자 승인으로 OCI 4 + RAW 6을 하나의 회차에 담았다. 재시도가 필요하면 성공 산출물의 재수집 비용과 실패 분리를 다시 검토하되, 모델과 repository archive는 여전히 제외한다.

## 복사할 목적 문구

- 회차 공통: `폐쇄망 ARM64 DGX Spark 2대에서 vLLM tensor parallelism 2와 LiteLLM 게이트웨이로 별도 승인된 DS4F 0731 및 GLM 5.3 Flash NVFP4 모델을 로컬 추론 서빙하기 위한 고정 버전 런타임·검증 자료`
- OCI image: `DGX Spark GB10/SM121 linux/arm64용 vLLM 또는 LiteLLM 실행 이미지; 두 노드 동일 digest 배치`
- eugr 개별 파일: `폐쇄망 DGX Spark 2대에서 검토된 로컬 recipe를 해석하고 rank·rendezvous를 주입하여 vLLM TP=2를 기동하기 위한 고정 commit 실행 파일`
- GLM top-k patch: `폐쇄망 DGX Spark의 GLM 5.3 Flash 장문 추론에서 SM121 sparse attention top-k 오류를 완화하기 위한 검토된 런타임 패치`
- PyYAML wheel: `폐쇄망 DGX Spark에서 eugr recipe 파서를 외부 pip 접속 없이 실행하기 위한 CPython 3.12 ARM64 wheel`

## 포털 밖에서 확인할 사항

- 허용 광매체 종류와 실제 용량
- community image의 CVE 예외 승인 기준
- `NOASSERTION` source의 license 기재 방식
- DFlash2 drafter의 CC-BY-NC-ND-4.0 출처 표시·license 사본 보존 및 비상업적 사용 기록
- 세 모델 별도 신청의 양식·승인권자·payload 검사 방식
- 외부 repository 참고자료와 자체 작성 repository의 별도 문서 반입 형식

이 항목은 포털 UI만으로 확정할 수 없으므로 보안·검역 담당자의 서면 답변을 신청 기록에 첨부한다.
