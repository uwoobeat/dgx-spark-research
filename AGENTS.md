# AGENTS.md

## Mission

이 저장소의 목적은 인터넷이 차단된 폐쇄망에서 ARM64 기반 NVIDIA DGX Spark 2대를 하나의 추론 클러스터로 구성하고, LiteLLM을 게이트웨이로 사용해 vLLM에서 지정 모델을 `tensor_parallel_size=2`로 서빙할 수 있는 재현 가능한 반입 목록과 작업 가이드북을 만드는 것이다.

대상 모델의 사용자 표기는 다음과 같다.

- DeepSeek V4 Flash 0731 (`DS4F`): 기본 공개 체크포인트만 운영 범위에 둔다. NVIDIA NVFP4 체크포인트는 별도 파일럿 범위이므로 본 반입·배포안에서 제외한다.
- GLM 5.3 Flash: 2×128GB 구성에 맞는 NVFP4 체크포인트를 배포 후보로 검토한다. 원본 FP8/BF16은 크기 비교와 배제 근거에만 사용한다.

이 표기는 조사 시작점일 뿐이다. 공식 배포 ID, 체크포인트 변형, 정밀도, 라이선스, 릴리스 날짜를 확인하기 전에는 확정된 제품명으로 취급하지 않는다. 이름이 부정확하거나 공개 배포되지 않았다면 임의로 다른 모델을 대체하지 말고 그 사실과 가능한 후보를 별도로 기록한다.

이 저장소는 같은 자산을 사용하되 목적이 다른 두 실행 단계를 지원한다.

1. **외부망 단계**: 인터넷에서 근거를 조사하고 immutable 버전·digest·checksum을 고정하며, 포털 OCI 반입·모델 별도 반입·런북 문서 반입 항목을 분리해 검역/반입을 준비한다.
2. **내부망 단계**: 승인된 자산과 별도 주입된 SSH 연결정보만 사용하여 두 DGX Spark를 점검·설정하고, `tp=2` 서비스 기동, LiteLLM 연결, 검증, 운영 및 장애 대응을 수행한다.

에이전트는 두 단계를 암묵적으로 오가지 않는다. 모드 판정, 전환 gate, 허용/금지 작업, 비밀 주입 규칙은 `docs/13-agent-modes.md`를 따른다. 이 지침을 작성하는 시점의 작업은 **외부망 모드**이지만, 지속적인 정본은 문서의 문구가 아니라 실행 세션의 `DGX_AGENT_MODE` 값이다. 값이 없거나 유효하지 않으면 fail-closed로 `external`을 적용한다.

## Required outcomes

최종 산출물은 최소한 다음 질문에 답해야 한다.

1. DGX Spark 출고·초기 설정 후 이미 설치되어 있는 하드웨어 지원 요소와 소프트웨어는 무엇인가?
2. 폐쇄망으로 추가 반입해야 할 Docker/OCI 이미지, 바이너리, OS 패키지, Python wheel, 모델 파일, 설정 파일은 무엇인가?
3. 각 아티팩트는 ARM64/aarch64 및 DGX Spark의 CUDA/드라이버 조합에서 실행 가능한가?
4. 인터넷 연결 PC에서 무엇을 내려받아 어떤 체크섬과 라이선스 정보를 남기고, 조직 승인 반입 포털(`QUARANTINE_BASE_URL`) 신청 및 승인 후 허용된 물리 매체로 어떻게 옮기는가?
5. 두 DGX Spark 사이의 네트워크를 어떻게 구성하고, vLLM 멀티노드 `tp=2`를 어떤 방식으로 실행하는가?
6. vLLM 공식 지원, 미병합 PR, 커뮤니티 패치, 별도 저장소 방식 사이의 차이와 위험은 무엇인가?
7. LiteLLM을 어떻게 연결하고 헬스 체크, 기능 검증, 성능 확인, 재시작, 로그 수집, 롤백을 수행하는가?
8. `eugr/spark-vllm-docker`를 DS4F와 GLM 5.3 Flash의 공통 실행·오케스트레이션 기반으로 쓸 수 있는가? 단일 image와 모델별 image 방식의 차이는 무엇인가?

## Expected repository structure

- `README.md`: 문서 지도, 현재 결론, 빠른 시작
- `docs/00-assumptions-and-decisions.md`: 확인된 전제, 미확정 사항, 결정 기록
- `docs/01-platform-baseline.md`: DGX Spark 하드웨어·OS·드라이버·기본 소프트웨어
- `docs/02-model-compatibility.md`: 정확한 모델 ID, 라이선스, 메모리/정밀도, 지원 현황
- `docs/03-recipe-comparison.md`: 공식·PR·커뮤니티 레시피 비교와 권고안
- `docs/03a-eugr-dual-model-review.md`: eugr 기반 양모델 공통화 가능성·충돌·채택 gate
- `docs/04-import-bom.md`: 폐쇄망 반입 BOM과 신청 단위
- `docs/05-online-staging.md`: 인터넷 연결 스테이징 호스트에서의 수집·검증·매체 작성
- `docs/06-airgap-deployment-guide.md`: DGX 반입 후 초기 설정부터 서비스 기동까지
- `docs/07-validation-and-operations.md`: 기능·성능 검증, 운영, 장애 대응, 롤백
- `docs/08-quarantine-portal.md`: 실제 검역 포털 입력·처리·산출물과 제출 단위
- `docs/09-completion-audit.md`: 요구사항별 증거·상태·남은 외부 gate
- `docs/10-separate-model-import-application.md`: 100–300 GB 모델 payload의 포털 외 별도 반입 신청 항목·증빙
- `docs/11-oci-model-content-audit.md`: 반입 OCI image에 모델 snapshot/weight가 포함되지 않았다는 검증 근거와 실물 검사 gate
- `docs/12-external-repository-reference-submission.md`: 외부 repository 참고자료의 별도 제출 목록과 자체 작성 자산의 provenance 분리 규칙
- `docs/13-agent-modes.md`: 외부망 조사/검역과 내부망 SSH 설치/운영의 실행 모드 계약 및 전환 gate
- `docs/14-ssh-harness.md`: 폐쇄망 SSH 기반 2노드 점검·기동·진단·rollback 하네스
- `docs/15-local-coding-agent-maintainability.md`: 작은 context의 로컬 코딩 에이전트 유지보수 계약과 평가 gate
- `INTERNAL_AGENT.md`: 폐쇄망 로컬 코딩 에이전트가 세션마다 먼저 읽을 compact 실행 계약
- `docs/source-ledger.md`: 출처 URL, 종류, 게시/확인 날짜, 뒷받침하는 주장
- `manifests/`: 이미지 digest, 파일 SHA-256, 패키지 lock 및 모델 파일 목록
- `configs/`: 검토 가능한 vLLM/LiteLLM/서비스 설정 예시
- `scripts/`: 온라인 수집과 오프라인 검증을 분리한 멱등성 스크립트

필요해질 때만 디렉터리와 파일을 만든다. 조사되지 않은 내용을 채우기 위해 빈 문서를 대량 생성하지 않는다.

## Source and evidence rules

1. 하드웨어 사양, 기본 설치 항목, 드라이버/CUDA/컨테이너 호환성은 NVIDIA 공식 문서를 최우선으로 한다.
2. vLLM 옵션과 지원 상태는 vLLM 공식 문서, 릴리스 노트, 저장소 코드, 이슈 및 PR의 정확한 commit을 확인한다. PR은 open/merged/closed 상태와 확인 날짜를 기록한다.
3. 모델 구성·아키텍처·라이선스는 모델 제작자의 공식 저장소와 공식 모델 카드/설정 파일을 우선한다.
4. 커뮤니티 레시피는 원문 URL과 commit SHA를 고정하고, 공식 지원과 명확히 구분한다. 재현 보고가 하나뿐이면 검증되지 않은 후보로 표시한다.
5. 중요한 사실은 가능한 한 독립된 2개 출처로 교차 확인한다. 단, 공식 manifest·config처럼 단일 1차 자료가 정본인 경우에는 예외를 설명한다.
6. 검색 결과 요약만 인용하지 않는다. 실제 문서·코드·PR을 열어 확인한다.
7. 모든 시점 의존 정보에는 `YYYY-MM-DD` 기준일을 붙인다. `latest`, `최근`, `현재`만으로 버전을 지정하지 않는다.
8. 확인된 사실, 계산/추론, 권고, 미확정 사항을 문서에서 구분한다.

## Architecture and compatibility gates

- 모든 실행 이미지와 바이너리는 `linux/arm64` 제공 여부를 manifest 또는 파일 메타데이터로 검증한다. 태그 존재만으로 호환된다고 판단하지 않는다.
- 컨테이너는 태그와 함께 immutable digest를 기록한다. 멀티아키텍처 index digest와 실제 ARM64 manifest digest를 구분한다.
- DGX OS, 커널, NVIDIA 드라이버, CUDA, NVIDIA Container Toolkit, PyTorch, vLLM, NCCL 조합을 하나의 호환성 매트릭스로 관리한다.
- DGX Spark/GB10의 compute capability, 지원 dtype/quantization, attention backend 및 커널 가용성을 확인한다.
- 2노드 `tp=2`는 단일 노드 2-GPU 설정과 다르다. launcher, rendezvous 주소, NIC 이름, NCCL interface, 방화벽/포트, Ray 또는 대체 executor 필요 여부를 명시한다.
- 모델 weight와 KV cache를 포함한 메모리 예산을 계산한다. 2대의 통합 메모리를 단순 합산해 단일 프로세스 메모리처럼 표현하지 않는다.
- 공식 지원 경로가 없다면 빌드 가능한 commit, 필요한 패치, 빌드 이미지, wheelhouse까지 반입 대상에 포함한다.
- eugr의 native recipe, launcher-only 재사용, B12X 단일 image 재빌드를 별도로 평가한다. 한 모델의 통과 결과를 다른 모델의 호환성 증거로 사용하지 않는다.

## Air-gap and import rules

- 폐쇄망에서 `apt`, `pip`, `git`, Hugging Face Hub, Docker registry 등 외부 네트워크 접근이 가능하다고 가정하지 않는다.
- 온라인 스테이징 단계와 폐쇄망 설치 단계를 명령어와 디렉터리 기준으로 완전히 분리한다.
- 반입 BOM에는 이름, 정확한 버전/commit, 아키텍처, 원본 URL/registry, 파일명, 크기, SHA-256, 라이선스, 의존 대상, 사용 목적, 필수/선택 구분을 둔다.
- OCI 이미지는 폐쇄망에서 load 가능한 archive로 준비하고, 모델은 remote code를 포함한 완전한 snapshot manifest로 고정한다.
- 모델 snapshot은 크기와 무관하게 조직 승인 반입 포털에 등록하거나 OCI image에 포함하지 않는다. DS4F, GLM target, DFlash2 drafter를 모델별 한 행으로 별도 모델 반입 신청서에 기재하고, 파일별 source inventory와 실제 payload SHA-256 manifest를 첨부한다.
- 포털 회차는 스크립트 코드·패키지 46건과 repository 소스코드 8건의 두 개로 분리한다. vLLM·LiteLLM을 포함한 모든 Docker/OCI image와 LLM 모델은 수동 반입한다. 포털에 image reference나 image archive를 입력하지 않는다.
- GitHub 등 외부 repository와 자체 repository는 고정 commit archive로 소스코드 전용 포털 회차에 신청한다. 기존 이미지·코드 회차와 혼합하지 않는다. 외부 원문과 자체 작성 자산의 provenance 및 승인 증빙은 항목별로 구분한다.
- Python 패키지는 전이 의존성을 포함한 ARM64 wheelhouse를 준비한다. wheel이 없어 소스 빌드가 필요하면 compiler/toolchain과 소스 tarball도 BOM에 포함한다.
- 허용된 물리 매체의 용량과 파일 크기를 고려해 매체 분할 계획, 매체별 manifest, 전체/개별 체크섬 검증 절차를 제공한다.
- 조직 승인 반입 포털의 실제 신청 필드와 정책은 근거 없이 추정하지 않는다. 공개 자료 또는 사용자가 제공한 양식이 없으면 범용 제출 패키지와 확인 필요 항목으로 구분한다.
- 비밀키, 토큰, 내부 IP, 비밀번호를 문서·스크립트·이미지에 포함하지 않는다.
- 로컬 포털 인증정보는 Git에서 제외된 `.env`에만 저장하고 파일 모드를 `0600`으로 유지한다. 화면 확인에 사용할 수 있으나 신청 제출·승인 요청·아티팩트 수집 실행은 사용자의 별도 승인 없이 수행하지 않는다.

## Implementation conventions

- 셸 스크립트는 기본적으로 `set -euo pipefail`을 사용하고, 변수 검증과 명확한 오류 메시지를 둔다.
- 예시 값은 `<NODE1_IP>`처럼 식별 가능한 placeholder로 표시한다. 그대로 실행되는 값과 교체할 값을 혼합하지 않는다.
- 명령은 대상 호스트(온라인 스테이징/DGX-1/DGX-2/관리 클라이언트)와 실행 권한을 함께 표시한다.
- 구성 파일과 스크립트는 가능하면 버전 고정, 재실행 안전성, 사전 점검, `--dry-run` 또는 검증 모드를 제공한다.
- 인터넷에서 받은 스크립트를 바로 실행하도록 안내하지 않는다. 저장하고 checksum/내용을 검토한 후 실행한다.
- 파괴적 초기화, 펌웨어 변경, 드라이버 교체는 명확한 필요성과 롤백 절차가 없으면 기본 경로에 넣지 않는다.

## Working sequence

1. 플랫폼 기준선과 사용자 환경에서 확인할 명령을 정의한다.
2. 정확한 모델 배포물과 vLLM 지원 상태를 확정한다.
3. 후보 실행 경로를 공식성, 재현성, ARM64 지원, 유지보수성, 성능, 반입 복잡도로 비교한다.
4. 권고 경로와 fallback 경로를 결정한다.
5. `eugr/spark-vllm-docker`가 DS4F와 GLM 5.3 Flash를 함께 운영하는 공통 기반이 될 수 있는지 소스·PR 적용성·image 계보·2노드 launcher 관점에서 검토한다.
6. 의존성 그래프에서 반입 BOM을 생성하고 immutable 버전과 checksum을 채운다.
7. 포털 OCI 반입, 모델 별도 반입, 런북 문서 반입을 분리한 온라인 수집 절차 및 폐쇄망 배포 절차를 작성한다.
8. 정적 검증 후 가능한 범위의 dry run/구문/구성 테스트를 수행한다.
9. 미확정 항목과 DGX 도착 후 확인할 acceptance checklist를 남긴다.

## Definition of done

다음이 모두 충족되어야 완료로 간주한다.

- 두 모델의 정확한 공개 배포물을 확인했거나, 확인 불가/미공개라는 결론을 근거와 함께 명시했다.
- 권고하는 vLLM/LiteLLM 실행 경로가 ARM64 DGX Spark 2대에서 가능한 이유와 남은 위험을 설명했다.
- eugr 기반 양모델 운영안의 가능 범위와 채택하지 않은 경로의 구체적인 이유를 기록했다.
- 필수 반입물에 버전/commit, 아키텍처, 원본, 크기, checksum 수집법, 라이선스가 있다.
- 폐쇄망 내부에서 외부 다운로드 없이 설치와 재설치가 가능하다.
- DGX 초기 점검, 2노드 통신/NCCL 점검, 모델별 서비스 시작, LiteLLM 연결, API smoke test가 순서대로 문서화되어 있다.
- 실패 시 로그 위치, 진단 명령, 롤백 또는 fallback이 있다.
- 모든 핵심 주장에 추적 가능한 출처가 있고, 기준일과 미확정 사항이 보인다.
- 문서의 명령·링크·파일 참조와 제공 스크립트의 구문을 검증했다.

## Local coding agent maintenance

- 폐쇄망 로컬 코딩 에이전트는 `AGENTS.md` 다음에 `INTERNAL_AGENT.md`와 `docs/13-agent-modes.md`를 읽고, 한 번에 하나의 작은 작업 단위만 수행한다.
- 특정 Qwen 모델명·context 크기·기억에 의존하지 말고 pinned profile, manifest, source ledger를 다시 읽어 판단한다.
- 첫 변경 전과 patch 후 `./scripts/validate-repository.sh`를 실행한다. 이 검사는 네트워크와 SSH를 사용하지 않는다.
- 내부망 SSH 또는 서비스 변경은 `internal` 진입 gate와 현재 작업에 대한 사람의 승인을 모두 요구한다. 로컬 검증 성공은 DGX 실기 acceptance를 대신하지 않는다.
