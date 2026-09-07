# 에이전트 실행 모드 계약

기준일: 2026-09-03

## 목적

이 저장소는 다음 두 단계에서 사용한다.

| 모드 | 단계 목적 | 대표 산출물/작업 |
|---|---|---|
| `external` | 외부망에서 조사, 버전 고정, 반입물 식별, 검역 및 별도 반입 준비 | 출처 원문 확인, digest/checksum/SBOM 수집, 포털 입력안, 별도 모델 신청서, 폐쇄망용 런북·하네스 작성 |
| `internal` | 반입된 저장소와 승인 자산으로 폐쇄망 DGX Spark를 설치·서빙·운영 | SSH 사전점검, 네트워크/NCCL 검증, OCI load, 모델 검증, `tp=2` 기동, LiteLLM 연결, smoke test, 로그/롤백 |

현재 대화에서 선언된 작업 모드는 `external`이다. 이 문장은 역사적 기록이며 다음 세션의 상태 정본으로 사용하지 않는다. 모드는 네트워크 연결 가능 여부, SSH 키 존재, 파일 경로 또는 이전 대화로 추론하지 않는다.

## 모드 선택과 전환

각 세션은 첫 번째 상태 변경 전에 다음 규칙으로 모드를 판정한다.

1. 사용자가 해당 세션에서 `외부망 모드` 또는 `내부망 모드`를 명시하면 그 선언을 사용한다.
2. 명시 선언이 없으면 프로세스 환경변수 `DGX_AGENT_MODE`를 읽는다. 허용값은 소문자 `external` 또는 `internal`뿐이다.
3. 값이 없거나 오타·충돌·해석 불가 상태이면 `external`로 fail-closed한다.

권장 실행 예시는 다음과 같다.

```bash
# 인터넷 연결 조사/검역 세션
export DGX_AGENT_MODE=external

# 승인 자산을 받은 폐쇄망 설치/운영 세션
export DGX_AGENT_MODE=internal
```

셸을 재시작해도 유지해야 한다면 저장소 밖의 운영자 전용 래퍼나 권한이 제한된 로컬 상태 파일에서 환경변수를 설정한다. 상태 파일은 Git에 추가하지 않고 내부 IP, 계정, 키 경로를 담지 않는다. 모드 자체는 비밀이 아니지만 저장소에 `현재 모드` 값을 커밋하면 시간이 지나 잘못된 실행을 유도하므로 금지한다.

모드는 자동 전환하지 않는다. `external` 작업 중 SSH 연결정보를 받더라도 사용자가 `internal` 전환을 명시하거나 새 세션을 그 모드로 시작하기 전에는 DGX에 접속하지 않는다. 반대로 `internal` 세션에서 누락 파일을 발견해도 인터넷 다운로드를 시도하지 않고 누락 목록과 checksum 요구사항을 외부망 작업 항목으로 반환한다.

## `external` 모드

### 허용

- NVIDIA, vLLM, 모델 제작자 및 고정 commit의 커뮤니티 원문 조사
- OCI manifest의 `linux/arm64` 확인, immutable digest·크기·라이선스·SBOM·checksum 수집 및 비교
- 모델 snapshot의 파일 inventory와 별도 모델 반입 신청서 작성
- 외부 repository 자료를 검토해 필요한 절차·설정·최소 자산을 이 저장소의 자체 런북/하네스로 구현
- 포털에 넣을 모델 미포함 runtime OCI image와 그 외 허용된 소형 바이너리의 신청 초안 작성
- 로컬 정적 검사, 구문 검사, mock/dry-run 및 문서 검증
- 사용자의 별도 실행 승인 후 포털 제출이나 승인된 온라인 수집 수행

### 금지

- DGX Spark 또는 그 관리망에 SSH 접속, 포트 검사, 파일 복사, 서비스 변경
- 내부 IP, 호스트명, 사용자명, SSH 키, 토큰 또는 실환경 비밀번호를 저장소에 기록
- 모델 snapshot/weight를 포털 RAW 항목이나 OCI layer에 포함
- GitHub repository archive 자체를 포털 반입 항목으로 제출하거나 repository에 대한 SBOM이 OCI SBOM을 대체한다고 취급
- 조사 결과만으로 DGX 실기 acceptance, RDMA/NCCL 성능 또는 모델 기동 성공을 `통과` 처리
- 검역 승인 전 자산을 내부망으로 이동했다고 가정

## `internal` 모드

### 진입 gate

다음 조건이 모두 확인되어야 변경 작업을 시작할 수 있다.

- `DGX_AGENT_MODE=internal` 또는 동일 세션의 명시적 사용자 선언
- 두 노드의 연결정보가 저장소 밖의 승인된 경로로 제공됨
- 반입 매체의 manifest/checksum과 모델별 payload manifest 검증 완료
- 필요한 ARM64 OCI archive, 모델, 설정, 런북이 로컬에 존재하며 외부 다운로드 없이 실행 가능
- 변경 대상 노드와 역할, 유지보수 시간 및 롤백 지점 식별

gate 미충족 시에는 로컬 문서 검토와 읽기 전용 사전점검 계획까지만 허용하고 변경은 중지한다.

### 허용

- 별도 주입된 SSH 설정으로 DGX-1/DGX-2의 읽기 전용 baseline 및 GPU/NIC 상태 점검
- 승인된 스크립트의 `--dry-run` 실행 후 사용자가 허용한 범위의 멱등 설치·구성
- OCI archive load, 모델 payload checksum 검증 및 읽기 전용 mount
- 노드 간 SSH/NCCL/RDMA 또는 TCP fallback acceptance, `tp=2` vLLM 기동, LiteLLM 연결
- health/API smoke test, 성능 측정, 로그 수집, 재시작과 문서화된 rollback
- 실측 결과를 비밀이 제거된 형태로 저장소 문서와 운영 기록에 반영

### 금지

- `apt`, `pip`, `git`, Hugging Face Hub, OCI registry, `curl` 등 외부 인터넷 접근 또는 런타임 자동 다운로드
- 누락 dependency를 임의 버전으로 대체하거나 온라인으로 보충
- 내부 연결정보·인증정보·실 IP를 tracked 파일, shell history, 로그 번들 또는 모델/config image에 포함
- 명시 범위를 벗어난 펌웨어·드라이버·OS 변경과 파괴적 초기화
- 한 노드의 성공을 두 노드 `tp=2`/NCCL acceptance로 간주
- 외부망 포털 작업과 내부망 DGX 변경을 한 세션에서 자동 연속 수행

## 비밀 및 연결정보 주입

저장소에는 `<DGX1_HOST>`, `<DGX2_HOST>`, `<DGX_SSH_USER>`, `<NCCL_IFNAME>` 같은 placeholder만 둔다. 실값은 다음 우선순위로 런타임에 주입한다.

1. 운영자가 관리하는 `~/.ssh/config`의 별칭과 SSH agent
2. 권한이 `0600`인 저장소 밖의 환경 파일 또는 secret manager가 생성한 단기 환경변수
3. 일회성 명령 인자(프로세스 목록이나 shell history에 노출되지 않는 경우에 한함)

개인키와 비밀번호를 환경변수에 직접 담는 방식은 피하고 SSH agent 또는 승인된 secret provider를 사용한다. 연결정보를 출력할 때는 host/IP, 사용자명, 토큰을 마스킹한다. 저장소 내부 `.env`는 검역 포털의 로컬 인증 용도로만 허용되며 Git에서 제외하고 `0600`을 유지한다. 내부망 DGX SSH 비밀 저장소로 재사용하지 않는다.

## Fail-closed 실행 규칙

- 실행 전 `mode`, 대상 환경, 네트워크 요구, 변경 여부를 한 줄로 선언한다. 예: `mode=internal target=DGX-1,DGX-2 network=airgap mutation=deploy`.
- 현재 모드와 요청 작업이 충돌하면 명령을 실행하지 않고 필요한 모드와 미충족 gate를 보고한다.
- 대상 host가 placeholder인지 실값인지 불명확하면 접속하지 않는다.
- 아키텍처, digest, checksum 또는 모델/OCI 분리가 확인되지 않으면 load·기동·반입 제출을 중지한다.
- 외부망에서는 내부망 성공을 추정하지 않고 `DGX 도착 후 확인` 상태로 유지한다.
- 내부망에서는 네트워크 오류를 온라인 재시도로 해결하지 않고 진단 자료와 누락 BOM을 외부망 단계로 넘긴다.
- 제출, 서비스 중지, 시스템 변경 등 상태 변경은 기존 문서의 승인 규칙을 그대로 적용한다. 모드 선택은 변경 승인을 대신하지 않는다.

## 하네스 설계 요구

내부망 SSH 자동화를 추가할 때는 다음 계약을 유지한다.

- inventory/config에는 placeholder와 역할만 commit하고 실 host mapping은 런타임에 주입한다.
- `preflight → checksum 검증 → baseline 수집 → 네트워크/NCCL acceptance → OCI load → 모델 mount → vLLM → LiteLLM → smoke test` 순서를 단계별로 재실행할 수 있게 한다.
- 모든 변경 스크립트는 가능하면 `--dry-run`, 대상 host 출력, 멱등성, 명시적 실패 코드와 rollback 안내를 제공한다.
- 노드별 stdout/stderr와 종료 코드를 분리 수집하되 비밀과 내부 식별자를 자동 마스킹한다.
- 외부 repository가 없어도 이 저장소와 승인 payload만으로 재설치할 수 있어야 한다.
