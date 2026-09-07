# 폐쇄망 로컬 코딩 에이전트 시작점

이 파일은 폐쇄망에 반입된 이 저장소를 로컬 코딩 에이전트가 유지보수할 때 사용하는 짧은 실행 계약이다. 사용자 표현인 특정 `Qwen 3.8` 제품명·성능·context 크기는 이 저장소에서 확인된 사실로 취급하지 않는다. 아래 절차는 **Qwen 계열을 포함한 모델 독립적 에이전트**가 작은 context에서도 한 번에 한 작업을 안전하게 처리하도록 설계한다.

## 세션 시작: 순서를 바꾸지 않는다

1. `AGENTS.md`, 이 파일, `docs/13-agent-modes.md`를 먼저 읽는다.
2. 사용자의 현재 세션 선언을 확인한다. 선언이 없으면 `DGX_AGENT_MODE`가 정확히 `external` 또는 `internal`인지 확인하고, 없거나 잘못되었으면 `external`로 fail-closed한다.
3. 첫 상태 변경 전에 `mode=<...> target=<...> network=<...> mutation=<...>`를 운영자에게 보고한다.
4. 저장소 root에서 `./scripts/validate-repository.sh`를 실행한다. 실패 항목을 우회하지 않는다.
5. 현재 요청에 필요한 문서와 파일만 추가로 읽는다. 모델 이름, 경로, digest, IP를 기억으로 보정하지 않는다.

`internal`은 인터넷 사용 허가가 아니다. 폐쇄망에서는 `apt`, `pip`, `git fetch/pull/clone`, Hugging Face/ModelScope, OCI registry, 외부 `curl/wget`을 시도하지 않는다. 누락 자산은 정확한 파일명·버전·checksum 요구사항으로 기록해 외부망 작업에 반환한다.

## 최소 문서 지도

| 하려는 일 | 먼저 읽을 정본 |
|---|---|
| 모드·비밀·전환 판단 | `docs/13-agent-modes.md` |
| DGX 초기 설치와 순서 | `docs/06-airgap-deployment-guide.md` |
| SSH 하네스 명령과 launcher | `docs/14-ssh-harness.md` |
| 장애 분류·검증·rollback | `docs/07-validation-and-operations.md` |
| OCI에 모델이 없는지 검사 | `docs/11-oci-model-content-audit.md` |
| 모델 payload 검증·반입 경계 | `docs/10-separate-model-import-application.md` |
| upstream 근거·provenance | `docs/12-external-repository-reference-submission.md`, `manifests/external-repository-references.tsv` |
| 잠금 버전·digest | `manifests/artifacts.lock.yaml`, `configs/profiles/` |

문서와 실행 파일이 다르면 실행을 멈추고 차이를 보고한다. 임의로 둘 중 하나를 정본으로 선택하지 않는다. 외부 upstream 참고자료와 이 저장소의 자체 문서·스크립트를 합치거나 출처를 지우지 않는다.

## 인터넷 없는 upstream 탐색 순서

1. 운영 결론은 먼저 자체 작성 영역에서 찾는다: `rg -n '<정확한 모델·오류·옵션>' README.md docs configs scripts manifests`.
2. `manifests/external-repository-references.tsv`에서 관련 E-ID와 40자리 pin을 확인한다.
3. 첫 upstream 조사 전에 `./scripts/verify-offline-repositories.sh --require-all`을 실행한다. 실패한 reference는 읽거나 실행 근거로 쓰지 않는다.
4. 검증된 원문만 좁혀 검색한다: `rg -n --hidden -g '!.git/**' '<정확한 symbol·error>' third_party/upstreams/E-03`.
5. 결과를 인용할 때 `E-ID@40자리 pin:상대경로:line`을 남긴다. upstream README/스크립트의 명령을 자체 runbook의 승인 명령처럼 바로 실행하지 않는다.

`third_party/upstreams/`는 read-only 외부 원문이며 이 public repository의 소유 코드가 아니다. 수정이 필요하면 자체 `configs/` 또는 `scripts/`에 최소 변경을 구현하고, upstream 원본 경로·pin과 patch 근거를 기록한다. reference가 누락됐거나 checksum이 다르면 인터넷을 시도하지 말고 필요한 E-ID, commit, 파일 또는 문서 캡처를 외부망 작업으로 반환한다. Git clone/archive에는 GitHub Issue·PR 댓글이 없을 수 있으므로 보이지 않는 토론 내용을 기억으로 채우지 않는다.

## 작은 context용 작업 단위

한 turn 또는 한 patch에는 한 가지 검증 가능한 목적만 둔다.

1. **범위:** 바꿀 파일과 바꾸지 않을 파일을 최대 3개 정도로 선언한다.
2. **근거:** 관련 정본의 정확한 절·profile·manifest 행을 읽는다.
3. **수용 조건:** 예: “두 profile의 digest는 유지되고 shell syntax와 repository validator가 통과한다.”
4. **변경:** 최소 diff만 만든다. 이름이 비슷한 모델/profile을 추측해 대체하지 않는다.
5. **정적 검증:** `./scripts/validate-repository.sh`와 변경 파일 전용 검사를 실행한다.
6. **실기 검증:** 필요한 경우에만, 올바른 모드와 승인 gate를 통과한 뒤 별도 작업으로 수행한다.
7. **인계:** 변경 파일, 근거, 실행한 검사, 미검증 항목, rollback을 짧게 남긴다.

작업이 context에 다 들어오지 않으면 `조사/근거 → config/profile → 정적 검사 → 단일 노드 사전점검 → 2노드 acceptance → 운영 변경`으로 나눈다. 앞 단계의 출력 파일과 checksum을 다음 단계 입력으로 사용한다. 여러 모델, launcher, 노드를 한꺼번에 고치지 않는다.

## 승인과 실행 gate

| 작업 | 조건 |
|---|---|
| 저장소 읽기, `bash -n`, 로컬 validator | 현재 모드에서 가능; 네트워크·SSH 없음 |
| `external` 조사/검역 실행 | 해당 절차의 사용자 승인; 포털 제출과 다운로드는 각각 실행 직전 확인 |
| `internal` SSH 읽기 점검 | 명시적 `internal`, 대상 2대·host key·승인 payload 확인, 실행 명령 사전 보고 |
| sync/load/launch/gateway start/stop/rollback | 위 gate + 운영자의 **현재 작업에 대한 명시적 승인** + 명령의 `--apply` |
| firmware/driver/OS 변경, 삭제, 파괴적 초기화 | 기본 금지; 승인된 별도 변경·rollback 계획 없이는 실행하지 않음 |

이전의 포괄 승인, 모드 설정 또는 SSH 자격정보 제공은 다음 상태 변경의 승인으로 간주하지 않는다. 에이전트는 승인 직전에 대상 노드, 명령, 영향, 되돌리는 방법을 다시 제시한다.

## 비밀과 내부 식별자

- 실제 IP, hostname, 계정, key 경로, API key, 토큰을 tracked 파일에 쓰지 않는다.
- `.env` 내용을 출력하지 않는다. `.env`는 포털용이며 mode `0600`과 Git 제외 상태만 검사한다.
- SSH는 검증한 `known_hosts`와 agent/저장소 밖 mode-0600 설정으로 주입한다. `StrictHostKeyChecking=no`로 우회하지 않는다.
- `state/diagnostics-*`는 민감한 내부 전용 자료다. public commit·외부 반출 전에는 별도 사본을 사람이 검토한다.
- shell trace(`set -x`), 전체 환경 출력, `docker inspect`의 환경 배열로 secret을 노출하지 않는다.

비밀을 발견하면 값을 반복하지 말고 파일 경로와 종류만 보고한다. 새 자격정보 생성, 회전, 폐기는 운영자에게 넘긴다.

## 내부망 장애 대응

1. 변경을 멈추고 어떤 profile/launcher/rank에서 처음 실패했는지 기록한다.
2. 서비스가 실행 중이면 `status` 후 `collect`로 worker/head 증거를 먼저 보존한다.
3. image config digest, 모델 tree manifest, patch SHA, rank, NIC/HCA, port 순서로 비교한다.
4. 인터넷 검색·다운로드나 임의 버전 대체를 하지 않는다.
5. 복구가 승인되면 시작 때 사용한 launcher/profile로 `stop ... --apply`하고, 문서화된 직전 profile로 rollback한다.
6. 실패 원인과 누락 자산이 외부망 조사를 요구하면 비밀을 제거한 요구사항만 인계한다.

실제 명령은 `docs/14-ssh-harness.md`를 따른다. 한 노드 성공을 TP=2 성공으로 기록하지 않으며, 실기 결과가 없으면 `검증 전`을 유지한다.

## 결정적 결과와 인계 형식

생성 목록은 `LC_ALL=C` 정렬하고, mutable tag 대신 고정 digest/commit/checksum을 쓴다. 로그에 현재 시각이 포함되어도 결론 파일명이나 비교 키는 profile ID·digest·test ID로 고정한다. 같은 입력에서 달라지는 자동 업그레이드, 온라인 resolve, “latest” 선택을 금지한다.

작업 종료 보고는 다음 다섯 줄을 기본으로 한다.

```text
mode/target: <mode와 대상; secret 제외>
changed: <파일 또는 없음>
evidence: <읽은 정본/manifest>
validated: <명령과 결과>
remaining: <실기 미검증, 승인 gate, rollback>
```

검사 통과는 저장소 정적 일관성만 의미한다. DGX의 GPU/RDMA/NCCL, TP=2 모델 기동, 응답 품질을 대신 증명하지 않는다.
