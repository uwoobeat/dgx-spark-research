# SSH 기반 2노드 운영 하네스

기준일: 2026-09-03

`scripts/cluster-harness.sh`는 폐쇄망 관리 워크스테이션에서 DGX-1과 DGX-2를 동일한 저장소·profile로 점검하고 기동하기 위한 하네스다. 실제 주소, 사용자명, 개인키 경로, `node.env`, LiteLLM master key는 저장소에 넣지 않는다.

## 에이전트 모드 경계

하네스는 프로세스 환경의 `DGX_AGENT_MODE`를 따른다. 설정 파일에는 이 값을 저장하지 않는다.

- `external` 또는 unset: 현재 조사·검역 단계다. 로컬 `validate`만 허용하고 SSH, 동기화, 기동, 중지, 진단 수집을 모두 거부한다.
- `internal`: 저장소와 승인 아티팩트가 폐쇄망에 있고 SSH 연결정보가 저장소 밖에서 주입된 세션에서만 사용한다.
- 다른 값: fail closed한다.

현재 외부망에서는 다음 정적 확인만 수행한다.

```bash
bash -n scripts/cluster-harness.sh
./scripts/cluster-harness.sh configs/cluster.env.example validate
```

내부망 진입은 새 세션에서 명시한다.

```bash
export DGX_AGENT_MODE=internal
```

## launcher 선택

`configs/cluster.env`의 `CLUSTER_LAUNCHER`는 다음 두 값만 허용한다.

| 값 | 역할 | 실행 주체 |
|---|---|---|
| `eugr` | 정상 운영 경로. 승인된 개별 eugr 파일과 custom recipe로 no-Ray TP=2 실행 | 중앙 하네스가 DGX-1에 접속하고, eugr가 DGX-1에서 DGX-2 worker를 먼저 dispatch |
| `native` | 독립 acceptance, eugr 장애 분석, rollback 경로 | 중앙 하네스가 DGX-2 worker와 DGX-1 head에 각각 직접 SSH |

`eugr`은 GitHub repository checkout을 사용하지 않는다. `REMOTE_EUGR_DIR`에는 포털에서 파일별 승인된 `run-recipe.sh`, `run-recipe.py`, `launch-cluster.sh`, `autodiscover.sh`만 배치하고 승인 SHA-256 manifest로 검증한다. `.git`, `.env`, `build-and-copy.sh`, `hf-download.sh`가 있으면 하네스가 실행을 거부한다.

eugr path에서 허용하는 profile mapping은 다음 두 개뿐이다.

- `configs/profiles/ds4f-base-acceptance.sh` → `configs/eugr-recipes/ds4f-base-offline.yaml`
- `configs/profiles/glm53-dflash2-operations.sh` → `configs/eugr-recipes/glm53-dflash2-offline.yaml`

`ds4f-base-dspark.sh`와 GLM v8 rollback profile은 승인된 eugr recipe mapping이 없으므로 `CLUSTER_LAUNCHER=native`에서만 실행한다. 하네스는 다른 profile을 유사하다고 추정해 eugr에 넘기지 않는다.

## 폐쇄망 최초 준비

관리 워크스테이션에서 다음 순서로 준비한다.

1. `configs/cluster.env.example`을 `configs/cluster.env`로 복사하고 `chmod 600`한다.
2. 두 관리 주소, SSH 사용자, key, 중앙 `known_hosts` 경로와 launcher를 채운다.
3. DGX-1용 node env는 `NODE_RANK=0`, DGX-2용은 `NODE_RANK=1`로 각각 만든다. `configs/node.env.example`의 fabric·RDMA·model 경로도 노드별로 바꾸고 두 파일을 `chmod 600`한다.
4. SSH host key fingerprint를 콘솔 등 독립 경로로 확인한 뒤 중앙 `known_hosts`에 저장하고 group/world 쓰기 권한을 제거한다. 하네스는 `StrictHostKeyChecking=yes`이며 새 key를 자동 신뢰하지 않는다.
5. SSH 사용자가 양 DGX에서 Docker를 사용할 수 있고 `REMOTE_REPO`를 소유하는지 확인한다.
6. DGX-1의 `REMOTE_LITELLM_ENV`에 `LITELLM_MASTER_KEY`를 두고 group/world 권한을 제거한다.
7. eugr 사용 시 DGX-1에서 DGX-2 fabric IP로 접속하는 승인 key를 별도로 배치하고, DGX-1 사용자 기본 경로 `$HOME/.ssh/known_hosts`의 fingerprint를 독립 확인한다. `REMOTE_EUGR_KNOWN_HOSTS`는 이 기본 경로와 같아야 한다.
8. eugr용 PyYAML은 `REMOTE_EUGR_PYTHONPATH`에 승인된 ARM64 wheel로 오프라인 설치한다.

```bash
chmod 600 configs/cluster.env state/dgx1.node.env state/dgx2.node.env
export DGX_AGENT_MODE=internal
./scripts/cluster-harness.sh configs/cluster.env validate
```

외부 모드의 `validate`는 config를 source하지 않고 데이터 전용 `KEY=value` 스키마, 허용 key, launcher enum, Bash 구문을 검사하며 미치환 placeholder 개수만 보고한다. 내부 모드의 `validate`는 여기에 실제 값, 로컬 파일, 권한과 포트 범위 검사를 더한다. `check`부터는 두 노드에 실제 SSH로 접속한다.

모델을 시작하기 전 각 노드에 load된 runtime image가 profile의 ARM64 config digest와 일치하고 어느 OCI layer나 최종 filesystem에도 모델 checkpoint signature가 없는지 검사할 수 있다. 이 검사는 전체 image를 stream하고 임시 container를 생성하므로 `--apply`가 필요하며 두 노드에서 순차 실행한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env image-audit \
  configs/profiles/ds4f-base-acceptance.sh --apply
```

## 설치 및 공통 preflight

```bash
# 두 DGX의 ARM64/Docker/GPU/필수 명령 확인
./scripts/cluster-harness.sh configs/cluster.env check

# 별도 문서 절차로 내부 반입된 이 저장소를 두 DGX에 배치
# rank별 node env를 함께 설치하므로 --apply 필수
./scripts/cluster-harness.sh configs/cluster.env sync --apply

# 상세 baseline은 내부 주소·serial을 포함하는 mode 0600 raw 파일이다.
./scripts/cluster-harness.sh configs/cluster.env baseline

# 이미지 digest, 모델 tree, NIC/RDMA, port, patch를 worker와 head 순서로 검사
./scripts/cluster-harness.sh configs/cluster.env preflight \
  configs/profiles/ds4f-base-acceptance.sh
```

`sync`는 `.git`, `.env*`, `configs/cluster*.env`, `state/`를 전송하지 않고 선택한 두 node env만 원격 `state/node.env`에 mode 0600으로 설치한다. 전송 전에 DGX-1 파일이 rank 0, DGX-2 파일이 rank 1인지 모두 검사하므로 한쪽만 먼저 바꾸는 부분 동기화를 줄인다.

eugr mode의 preflight는 공통 검사에 더해 다음을 모두 확인한다.

- 네 실행 파일의 존재·비쓰기 권한·승인 SHA-256 manifest
- shell/Python 정적 구문과 `REMOTE_EUGR_PYTHONPATH`의 PyYAML import
- repository/download 도구가 eugr 실행 디렉터리에 섞이지 않았음
- DGX-1→DGX-2 `BatchMode=yes`, strict host-key SSH와 worker Docker 접근

## eugr 정상 운영

`CLUSTER_LAUNCHER=eugr`로 설정하고 profile에 맞는 명령 하나를 중앙 관리 워크스테이션에서 실행한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env launch \
  configs/profiles/ds4f-base-acceptance.sh --apply

./scripts/cluster-harness.sh configs/cluster.env status \
  configs/profiles/ds4f-base-acceptance.sh
./scripts/cluster-harness.sh configs/cluster.env smoke \
  configs/profiles/ds4f-base-acceptance.sh
```

하네스는 양 노드 native preflight를 다시 실행하고 eugr gate를 통과한 뒤 DGX-1의 승인 `run-recipe.sh`를 호출한다. eugr no-Ray launcher가 worker rank 1을 먼저 `docker exec -d`하고 head rank 0을 나중에 시작한다. 하네스는 이후 DGX-1의 `:8000/health`가 `HEALTH_TIMEOUT_SECONDS` 안에 응답하는지 확인한다.

GLM DFlash2는 target, drafter, 승인 patch와 cache를 각각 mount한다. `/srv/vllm-cache/glm53-dflash2` 또는 node env의 `CACHE_HOST_PATH`가 양 노드에 미리 존재하지 않으면 실행하지 않는다.

```bash
./scripts/cluster-harness.sh configs/cluster.env launch \
  configs/profiles/glm53-dflash2-operations.sh --apply
```

eugr의 고정 실행 파일은 내부 SSH 명령 일부에 `StrictHostKeyChecking=no`를 사용한다. 하네스는 이를 수정하지 않아 승인 checksum을 보존한다. 대신 실행 직전에 DGX-1 기본 `known_hosts`가 지정 경로와 같은지 확인하고 같은 DGX-2 fabric IP에 `StrictHostKeyChecking=yes`로 접속·Docker 접근을 선행 검증한다. 이 보완 gate가 실패하면 eugr를 호출하지 않는다.

## native 독립·rollback 운영

`CLUSTER_LAUNCHER=native`는 중앙 관리 워크스테이션의 검증된 SSH 설정만 사용한다. worker를 먼저 시작하고 기본 10초 동안 container가 계속 실행 중인지 확인한 뒤 head를 시작한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env launch \
  configs/profiles/glm53-nvfp4-acceptance.sh --apply
```

DSpark profile도 native lane에서만 선택한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env launch \
  configs/profiles/ds4f-base-dspark.sh --apply
```

health timeout이나 head 실패 시 worker를 자동 삭제하지 않는다. 먼저 `status`와 `collect`로 증거를 확보한 뒤 시작할 때 사용한 launcher 설정으로 명시적으로 중지한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env stop \
  configs/profiles/glm53-dflash2-operations.sh --apply
```

eugr stop은 승인 `launch-cluster.sh`에서 head와 worker를 중지한다. native stop은 중앙 하네스가 head 다음 worker의 container를 중지·삭제한다. 어느 경로든 마지막에 양 노드에 같은 이름의 container가 남았는지 검사하고 남아 있으면 실패로 보고한다.

## LiteLLM

LiteLLM은 DGX-1에서 vLLM의 loopback `:8000`을 바라보고 `:4000`을 제공한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env gateway-start --apply
./scripts/cluster-harness.sh configs/cluster.env gateway-status
./scripts/cluster-harness.sh configs/cluster.env gateway-smoke ds4f-base
./scripts/cluster-harness.sh configs/cluster.env gateway-stop --apply
```

`gateway-start`와 `gateway-smoke`는 원격 env 파일이 존재하고 group/world 접근 권한이 없는지 확인한 뒤에만 secret을 프로세스 환경으로 읽는다. 명령 출력이나 이 저장소에는 master key를 기록하지 않는다.

## 진단과 복구

```bash
./scripts/cluster-harness.sh configs/cluster.env collect \
  configs/profiles/glm53-dflash2-operations.sh
```

기본 출력은 로컬 `state/diagnostics-<시각>/`이며 mode 0700 디렉터리 안에 노드별 mode 0600 파일을 만든다. 내부 주소, GPU 상태, container 설정과 로그가 포함되므로 외부망으로 반출하거나 public repository에 commit하지 않는다.

LiteLLM container의 `docker inspect`는 master key가 환경 배열에 나타날 수 있으므로 수집하지 않고 로그만 모은다. 원본 진단 파일은 sanitize되지 않은 내부 전용 자료다. 외부 공유본이 필요하면 IP, hostname, 사용자 경로, 모델 경로, prompt/response를 별도 사본에서 제거하고 사람이 재검토해야 하며, 단순 정규식 치환 결과를 곧바로 반출 가능 자료로 간주하지 않는다.

기동 실패 시 다음 순서로 처리한다.

1. `status`와 `collect`로 양 rank 로그를 보존한다.
2. worker/head의 profile, image config digest, 모델 tree manifest가 같은지 확인한다.
3. `node.env`에서 rank, fabric IP, NIC, HCA가 노드별로 맞는지 확인한다.
4. `stop PROFILE --apply`로 container를 제거한다.
5. 설정을 수정했다면 `sync --apply`와 `preflight`부터 반복한다.

하네스는 firmware 변경, driver 교체, model download, image pull, repository clone을 수행하지 않는다. 모델·image·개별 eugr 실행 파일은 승인된 별도 반입 payload를 사전에 배치해야 하며 폐쇄망에서 외부 registry, GitHub, Hugging Face Hub에 접속하지 않는다.
