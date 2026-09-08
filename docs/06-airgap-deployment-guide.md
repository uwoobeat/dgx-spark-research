# 폐쇄망 배포 가이드

이 절차는 승인 payload와 별도 반입된 본 저장소가 폐쇄망에 있고 DGX Spark 2대의 SSH 연결정보가 저장소 밖에서 제공된 뒤 수행한다. 현재 조사 세션은 `external` 모드이므로 아래 명령을 아직 실행하지 않는다. 실제 작업은 새 세션에서 `DGX_AGENT_MODE=internal`을 명시하고 [모드 진입 gate](13-agent-modes.md)를 통과한 뒤 시작한다. 중앙 명령의 상세 계약은 [SSH 기반 2노드 운영 하네스](14-ssh-harness.md)에 있다. 예시 placeholder는 실제 폐쇄망 설계값으로 바꾼다.

## 0. 역할과 변수

| 역할 | 예시 |
|---|---|
| DGX-1 | rank 0, vLLM API, LiteLLM gateway |
| DGX-2 | rank 1, headless worker |
| fabric | 직접 QSFP/RoCE, `<DGX1_FABRIC_IP>/<PREFIX>`, `<DGX2_FABRIC_IP>/<PREFIX>` |
| management | client/API/SSH용 별도 subnet |
| model root | 두 노드 모두 `/srv/models/<MODEL>` |
| image archive | `/srv/import/images` |
| repository harness | 두 노드의 `REMOTE_REPO`; 실제 값은 ignored `configs/cluster.env`로 주입 |
| approved eugr files | 두 노드 모두 `/opt/approved/eugr-launcher` |
| approved GLM patch | 두 노드 모두 `/opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py` |

내부 IP, NIC, HCA 이름은 저장소에 commit하지 않는다. 관리 workstation의 `state/dgx1.node.env`, `state/dgx2.node.env`를 각각 `0600`으로 만들고 SSH 하네스가 두 노드의 `$REMOTE_REPO/state/node.env`로 배치하게 한다. SSH host, user, key 경로는 ignored `configs/cluster.env`에만 둔다.

### 0.1 SSH 하네스 준비

관리 workstation에서 out-of-band로 받은 host key fingerprint를 검증한 뒤 `state/known_hosts`를 만든다. 신뢰 근거 없이 `StrictHostKeyChecking=no`나 미검증 `ssh-keyscan` 결과를 사용하지 않는다.

```bash
export DGX_AGENT_MODE=internal
mkdir -p state
cp configs/cluster.env.example configs/cluster.env
cp configs/node.env.example state/dgx1.node.env
cp configs/node.env.example state/dgx2.node.env
test -s state/known_hosts
chmod 600 configs/cluster.env state/dgx1.node.env state/dgx2.node.env state/known_hosts
# placeholder를 승인된 실값으로 교체하고 DGX-2 node.env의 NODE_RANK를 1로 지정
# 정상 경로는 CLUSTER_LAUNCHER=eugr, 독립/rollback 경로만 native
./scripts/cluster-harness.sh configs/cluster.env check
```

`check`는 두 SSH target의 ARM64, Docker, GPU와 필수 command를 읽기 전용으로 확인한다. 이후 저장소를 두 노드로 내부 복제할 때만 다음 명령을 실행한다. `sync`는 `.git`, `.env`, local state를 전송하지 않고 노드별 `node.env`만 `0600`으로 주입한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env sync --apply
```

실제 연결정보와 비밀은 commit, 문서, 진단 bundle에 넣지 않는다. `--apply`가 필요한 변경 작업은 대상과 rollback 지점을 확인한 뒤에만 수행한다.

## 1. 매체와 장비 무결성

두 노드에서 시간, hostname, disk를 확인한다. 한 노드에 승인 payload를 복사한 뒤 매체 manifest를 검증하고 동일 payload를 두 번째 노드로 승인된 내부 방식으로 복사한다.

```bash
./scripts/verify-sha-manifest.sh /mnt/import-media media-01.sha256
sudo ./scripts/collect-dgx-baseline.sh /var/tmp/dgx-baseline
diff -u dgx1-baseline/summary.txt dgx2-baseline/summary.txt
```

driver/firmware가 다르면 모델 설치를 중지하고 동일 baseline으로 맞춘다. firmware/recovery 작업은 별도 승인과 백업 후 수행한다.

## 2. QSFP/RoCE 구성

1. 전원을 끈 상태에서 승인 cable로 동일 계열 QSFP port를 연결한다.
2. 부팅 후 `ip -br link`, `ibdev2netdev`, `rdma link`로 Linux netdev/RDMA mapping을 기록한다.
3. NVIDIA Sync Cluster Assistant를 사용할 수 있으면 link와 SSH를 확인한다. 해당 assistant는 2026-04 이후 software를 요구한다.
4. 수동 구성 시 양쪽 interface에 고정 IP와 같은 MTU를 설정한다. NetworkManager profile 이름은 조직 표준을 따른다.
5. 관리망 경로와 fabric 경로가 섞이지 않는지 `ip route get <PEER_FABRIC_IP>`로 확인한다.

기능 점검:

```bash
ping -I <FABRIC_IFACE> -c 5 <PEER_FABRIC_IP>
rdma link
ibdev2netdev
```

NCCL test binary를 별도 반입하지 않은 최소안에서는 vLLM image의 PyTorch distributed smoke를 사용한다. 성능 기준이 필요하면 ARM64로 빌드한 `nccl-tests` image와 source/license를 BOM에 추가한다.

모델을 올리기 전에 두 콘솔에서 worker(DGX-2)를 먼저 실행하고 head(DGX-1)를 이어 실행한다.

```bash
REPO_ROOT='<REMOTE_REPO_FROM_CLUSTER_ENV>'
cd "$REPO_ROOT"
sudo -E ./scripts/run-nccl-smoke.sh state/node.env
```

양 rank가 `NCCL_SMOKE_OK`를 출력해야 한다. `NCCL_DEBUG=INFO` log에서 실제 RoCE transport를 확인한다.

## 3. swap과 host 설정

host memory 정책은 profile별로 다르다. DS4F acceptance profile은 swap off를 요구한다. tonyd2wild GLM 경로는 모델 load/repack 중 완전한 swap off에서 worker가 죽을 수 있다고 보고하므로, GLM에서는 승인된 swap을 활성화하되 `vm.swappiness=0`을 요구한다.

```bash
swapon --show
sysctl vm.swappiness
```

GLM 실행 전에 두 노드 모두 swap 장치가 표시되고 `vm.swappiness`가 `0`이어야 한다. 영구 설정과 swap 파일 생성은 host 변경이므로 보안·운영 승인을 거친다. page cache를 반복적으로 강제 drop하는 것은 기본 부팅 절차에 넣지 않는다.

## 4. OCI image load와 검증

검역 결과가 OCI archive 또는 Docker archive 중 무엇인지 먼저 확인한다. Docker archive 예시는 다음과 같다.

```bash
docker load --input /srv/import/images/<APPROVED-IMAGE>.tar
docker image inspect '<IMAGE@sha256:DIGEST>' \
  --format '{{.Os}}/{{.Architecture}} {{.Id}} {{join .RepoDigests ","}}'
```

두 노드에서 출력이 동일하고 `linux/arm64`인지 확인한다. digest ref가 load 후 local name으로 직접 resolve되지 않으면 승인 manifest에 기록된 image ID에 local alias를 붙이고 두 노드의 ID 일치를 검증한다. 태그만 비교하지 않는다.

```bash
# 예: 양 노드에서 승인 manifest의 config digest를 local alias로 고정
docker tag sha256:f89e9baedf38ffe3165641d4a937b59b227bbbd58d0116a7518c53b97d601823 \
  airgap/ds4f-b12x:approved
docker tag sha256:35c6f70ffcba62fd67d7b9d4b4e8300ad177201792ce9cdb1ea18fd449bc23b6 \
  airgap/glm53-dflash2:approved
```

launcher는 각 profile의 image config digest(`docker inspect .Id`)까지 검사한다. archive load가 registry digest 이름을 보존하지 않았을 때만 `DS4F_BASE_IMAGE_LOCAL_REF`, `GLM53_IMAGE_LOCAL_REF`, `GLM53_DFLASH2_IMAGE_LOCAL_REF`에 local alias를 넣는다.

## 5. 모델 배치

모델은 두 노드의 동일 absolute path에 둔다. 별도 반입 payload가 승인 매체 제약 때문에 분할돼 있으면 먼저 staging 경로에서 재조립하고 전체 manifest를 통과한 뒤 최종 경로로 이동한다. 포털 5 GB 제한 때문에 분할하는 것은 아니다.

```bash
./scripts/verify-model-tree.sh \
  /srv/models/DeepSeek-V4-Flash-0731 \
  /srv/import/manifests/ds4f-base.files.tsv
```

필수 확인:

- LFS pointer text가 아니라 실제 binary가 있는가.
- safetensors index가 가리키는 shard가 모두 있는가.
- config/tokenizer/processor/chat template/remote code가 있는가.
- directory와 파일 SHA가 두 노드에서 같은가.
- vLLM container uid가 read할 수 있고 model mount는 read-only인가.

GLM 운영 시에는 DFlash2 drafter도 두 노드의 `/srv/models/GLM-5.3-Flash-DFlash2`에 완전한 5-file tree로 두고 별도 tree manifest를 검증한다.

## 6. node.env

관리 workstation에서 `configs/node.env.example`을 복사해 두 노드용 파일을 따로 만든다. 비밀이 아닌 network 값도 환경별이므로 Git에는 넣지 않는다. 아래는 내용 예시이며 하네스는 각 파일을 대상 노드의 `$REMOTE_REPO/state/node.env`에 mode `0600`으로 설치한다.

```bash
NODE_RANK=0                       # DGX-2는 1
HEAD_FABRIC_IP="<HEAD_FABRIC_IP>"
THIS_FABRIC_IP="<THIS_FABRIC_IP>"
PEER_FABRIC_IP="<PEER_FABRIC_IP>"
FABRIC_CIDR="<FABRIC_CIDR>"
FABRIC_IFACE="<FABRIC_IFACE>"
RDMA_HCA="<RDMA_HCA>"
MASTER_PORT=29521
MODEL_HOST_PATH=/srv/models/DeepSeek-V4-Flash-0731
MODEL_TREE_MANIFEST=/srv/import/manifests/ds4f-base.files.tsv
MODEL_TREE_MANIFEST_SHA256='<별도 반입 신청에 기록된 64자리 manifest SHA-256>'
DS4F_BASE_IMAGE_LOCAL_REF=airgap/ds4f-b12x:approved
# GLM DFlash2 profile에서만 추가
# MODEL_HOST_PATH=/srv/models/GLM-5.3-Flash-NVFP4
# MODEL_TREE_MANIFEST=/srv/import/manifests/glm53-redhat-nvfp4.files.tsv
# MODEL_TREE_MANIFEST_SHA256='<별도 반입 신청에 기록된 64자리 manifest SHA-256>'
GLM53_DFLASH2_IMAGE_LOCAL_REF=airgap/glm53-dflash2:approved
GLM_PATCH_HOST_PATH=/opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py
DRAFT_MODEL_HOST_PATH=/srv/models/GLM-5.3-Flash-DFlash2
DRAFT_MODEL_TREE_MANIFEST=/srv/import/manifests/glm53-dflash2-draft.files.tsv
DRAFT_MODEL_TREE_MANIFEST_SHA256='<별도 모델 반입 신청에 기록된 64자리 manifest SHA-256>'
```

```bash
chmod 600 state/dgx1.node.env state/dgx2.node.env
```

`FABRIC_IFACE`와 `RDMA_HCA`는 문서의 예시를 복사하지 말고 실제 mapping을 사용한다.
모델을 바꿀 때 `MODEL_HOST_PATH`, `MODEL_TREE_MANIFEST`, `MODEL_TREE_MANIFEST_SHA256`도 같은 승인 모델 묶음으로 함께 바꾼다. 전체 tree hashing 때문에 preflight에 시간이 걸리지만 exact revision 검증을 생략하지 않는다.

## 7. eugr 공통 launcher 준비

GitHub repository archive를 풀지 않는다. 포털에서 파일 단위로 승인된 `run-recipe.sh`, `run-recipe.py`, `launch-cluster.sh`, `autodiscover.sh`만 두 노드의 `/opt/approved/eugr-launcher`에 배치하고 승인 manifest로 각각 검증한다. `launch-cluster.sh`는 명시적 NIC/node 옵션을 사용해도 `autodiscover.sh`를 source하므로 이 파일을 생략할 수 없다. root license, upstream README·Dockerfile·issue 같은 참고자료는 별도 참고자료 문서에서 관리하고 이 실행 디렉터리에 섞지 않는다.

```bash
REPO_ROOT='<REMOTE_REPO_FROM_CLUSTER_ENV>'
"$REPO_ROOT/scripts/verify-sha-manifest.sh" \
  /opt/approved/eugr-launcher \
  /srv/import/manifests/eugr-launcher-files.sha256
sudo chmod 0755 /opt/approved/eugr-launcher/run-recipe.sh \
  /opt/approved/eugr-launcher/run-recipe.py \
  /opt/approved/eugr-launcher/launch-cluster.sh \
  /opt/approved/eugr-launcher/autodiscover.sh
```

`run-recipe.sh`는 PyYAML이 없으면 인터넷 `pip install`을 시도할 수 있으므로 승인된 개별 ARM64 wheel을 local target에 먼저 설치한다.

```bash
python3 -VV
python3 -c 'import sys; assert sys.version_info[:2] == (3, 12), sys.version'
python3 -c 'import sysconfig; assert "aarch64" in (sysconfig.get_config_var("SOABI") or ""), "ARM64 Python required"'
python3 -m pip --version
sudo install -d -m 0755 /opt/approved/eugr-python
sudo python3 -m pip install --no-index --no-deps \
  --target /opt/approved/eugr-python \
  /srv/import/wheels/pyyaml-6.0.3-cp312-cp312-manylinux2014_aarch64.manylinux_2_17_aarch64.manylinux_2_28_aarch64.whl
PYTHONPATH=/opt/approved/eugr-python python3 -c 'import yaml; print(yaml.__version__)'
```

승인 wheel은 CPython 3.12 ARM64용이다. 장비의 `python3` ABI가 3.12가 아니면 설치를 강행하지 말고, 같은 PyYAML version의 해당 `cp3XY` ARM64 wheel을 새로 식별·승인한다.

Python 또는 pip 검사 실패 시 여기서 중단한다. [선제 반입한 Python ARM64 패키지의 설치 gate](17-python-arm64-import.md)에 따라 DGX OS 호환성을 확인한 뒤 필요한 `.deb`와 전이 의존성을 먼저 설치한다. 기존 x86용 Python 3.12를 대신 설치하거나 외부 `get-pip.py`를 실행하지 않는다. 다른 Python minor 버전 채택은 가능하지만 현재 cp312 wheel과 하네스 ABI 검증을 함께 변경해야 한다.

폐쇄망에서는 `--setup`, `--build-only`, `--download-only`, `--apply-vllm-pr`를 사용하지 않는다. `build-and-copy.sh`와 `hf-download.sh`는 반입하지 않는다. custom recipe에는 모델 Hub ID가 없고 local path만 있으므로 외부 다운로드가 필요하지 않다.

## 8. vLLM TP=2 시작

정상 운영 경로는 `configs/cluster.env`의 `CLUSTER_LAUNCHER=eugr`다. 관리 workstation에서 하네스 명령을 한 번 실행하면 DGX-1의 승인 eugr 파일이 DGX-2 worker rank를 먼저, DGX-1 head rank를 뒤에 실행한다. 운영자가 두 rank를 따로 실행하지 않는다.

`CLUSTER_LAUNCHER=native`는 eugr 장애 분석, 독립 acceptance·rollback용 fail-safe다. 이 경로에서는 관리 workstation이 같은 profile로 DGX-2 worker를 먼저 원격 실행하고 설정한 안정화 시간 뒤 DGX-1 head를 시작한다. 어느 lane이든 launcher는 architecture, image config digest, model `config.json` identity, NIC/HCA route, peer ping, swap, port, patch/wrapper SHA를 검사하고 하나라도 다르면 실행하지 않는다. 실행 중 lane을 바꾸지 않으며, 바꾸려면 기존 두 rank를 먼저 완전히 중지한다.

### 8.1 독립 preflight·rollback 경로

`configs/cluster.env`에서 `CLUSTER_LAUNCHER=native`를 명시하고 관리 workstation에서 SSH 하네스로 두 노드의 preflight를 worker부터 실행한다. 이 lane 선택은 실행 기록에 남긴다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  preflight configs/profiles/ds4f-base-acceptance.sh
```

독립 launcher lane으로 기동해야 할 때도 관리 workstation에서 한 명령만 실행한다. 하네스가 DGX-2를 먼저 시작하고 DGX-1을 뒤에 시작하며, head health가 timeout 안에 열리지 않으면 실패한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  launch configs/profiles/ds4f-base-acceptance.sh --apply
./scripts/cluster-harness.sh configs/cluster.env \
  status configs/profiles/ds4f-base-acceptance.sh
./scripts/cluster-harness.sh configs/cluster.env \
  smoke configs/profiles/ds4f-base-acceptance.sh
```

직접 head console에서 확인할 때의 최소 명령은 다음과 같다.

```bash
docker logs -f vllm-ds4f-base
curl -fsS http://127.0.0.1:8000/health
curl -fsS http://127.0.0.1:8000/v1/models | jq .
```

### 8.2 정상 eugr 운영 경로

`configs/cluster.env`에서 `CLUSTER_LAUNCHER=eugr`를 명시한다. 관리 workstation에서 해당 모델 profile로 본 저장소 preflight를 먼저 실행하면 각 노드의 `$REMOTE_REPO/state/node.env` 검사와 DGX-1→DGX-2 passwordless SSH, eugr 개별 파일 manifest/PyYAML gate까지 수행한다. `MODEL_HOST_PATH`와 manifest 변수는 현재 시작할 모델과 일치해야 한다. GLM DFlash2 예시는 다음과 같다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  preflight configs/profiles/glm53-dflash2-operations.sh
```

정상 기동도 같은 중앙 명령으로 수행한다. 하네스가 DGX-1에서 승인 eugr recipe runner를 호출하고 head health를 기다린다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  launch configs/profiles/glm53-dflash2-operations.sh --apply
./scripts/cluster-harness.sh configs/cluster.env \
  status configs/profiles/glm53-dflash2-operations.sh
./scripts/cluster-harness.sh configs/cluster.env \
  smoke configs/profiles/glm53-dflash2-operations.sh
```

아래는 하네스가 구성하는 eugr 호출의 확장 예시다. 장애 분석 때 인자를 대조하는 용도이며 정상 기동 시 이 명령을 중앙 하네스와 중복 실행하지 않는다. host path는 양 노드에 동일하게 존재해야 하며 NIC/HCA/GID는 실제 값으로 바꾼다. eugr는 임의로 추가한 cache volume의 host directory를 만들지 않으므로 GLM cache directory도 양 노드에 미리 만든다.

```bash
# 양 노드에서 각각 실행
sudo install -d -m 0750 /srv/vllm-cache/glm53-dflash2
```

DGX-1에 SSH로 접속한 뒤 승인 repository 위치를 명시하고 DS4F base를 시작한다. eugr 자체가 DGX-1에서 DGX-2로 SSH하므로 별도의 승인된 node-to-node key와 검증된 host key가 필요하다.

```bash
REPO_ROOT='<REMOTE_REPO_FROM_CLUSTER_ENV>'
source "$REPO_ROOT/state/node.env"
cd /opt/approved/eugr-launcher
PYTHONPATH=/opt/approved/eugr-python ./run-recipe.sh \
  "$REPO_ROOT/configs/eugr-recipes/ds4f-base-offline.yaml" \
  -t airgap/ds4f-b12x:approved \
  --no-ray -d \
  -n "$HEAD_FABRIC_IP,$PEER_FABRIC_IP" \
  --eth-if "$FABRIC_IFACE" --ib-if "$RDMA_HCA" \
  --master-port "$MASTER_PORT" --name vllm-ds4f-base \
  -e "NCCL_IB_ADDR_RANGE=$FABRIC_CIDR" \
  -v /srv/models/DeepSeek-V4-Flash-0731:/models/ds4f:ro
```

GLM DFlash2 시작:

```bash
REPO_ROOT='<REMOTE_REPO_FROM_CLUSTER_ENV>'
source "$REPO_ROOT/state/node.env"
cd /opt/approved/eugr-launcher
PYTHONPATH=/opt/approved/eugr-python ./run-recipe.sh \
  "$REPO_ROOT/configs/eugr-recipes/glm53-dflash2-offline.yaml" \
  -t airgap/glm53-dflash2:approved \
  --no-ray -d \
  -n "$HEAD_FABRIC_IP,$PEER_FABRIC_IP" \
  --eth-if "$FABRIC_IFACE" --ib-if "$RDMA_HCA" \
  --master-port "$MASTER_PORT" --name vllm-glm53-dflash2 \
  -e "NCCL_IB_ADDR_RANGE=$FABRIC_CIDR" \
  -v /srv/models/GLM-5.3-Flash-NVFP4:/models/glm53:ro \
  -v /srv/models/GLM-5.3-Flash-DFlash2:/models/dflash2-draft:ro \
  -v /srv/vllm-cache/glm53-dflash2:/cache \
  -v /opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/layers/sparse_attn_indexer_kpool.py:ro
```

eugr는 worker에 `--node-rank 1 --headless`, head에 `--node-rank 0`과 공통 rendezvous 인자를 자동 추가한다. recipe에 이 인자를 중복해서 넣지 않는다. eugr container는 vLLM이 죽어도 keepalive 상태로 남을 수 있으므로 `docker ps`만 보지 말고 `/health`, `docker top`, 두 rank log를 확인한다.

tonyd2wild 수동 launcher와 달리 eugr는 worker dispatch 뒤 고정 25초를 기다리지 않는다. 정상이라면 분산 rendezvous에서 서로를 기다리지만, acceptance에서 cold boot를 3회 반복해 rank timeout이 없는지 확인한다. race가 재현되면 운영 투입하지 말고 eugr source에 명시적 delay를 넣은 내부 변경판을 새 checksum으로 재승인하거나 독립 launcher를 사용한다.

```bash
curl -fsS http://127.0.0.1:8000/health
docker top vllm-glm53-dflash2
```

profile 순서:

1. `ds4f-base-acceptance.sh`
2. 기능 검증 후 `ds4f-base-dspark.sh`
3. `glm53-nvfp4-acceptance.sh` + `sm121-v8` rollback lane
4. `glm53-dflash2-operations.sh` 또는 eugr DFlash2 custom recipe

모델을 바꿀 때는 기동에 사용한 것과 같은 lane/profile로 중앙 stop을 호출한다. eugr lane이면 하네스가 DGX-1에서 low-level `stop` action을 호출한다.

```bash
./scripts/cluster-harness.sh configs/cluster.env \
  stop configs/profiles/glm53-dflash2-operations.sh --apply
```

아래는 eugr stop의 확장 진단 예시다. `--name`은 시작할 때 사용한 이름과 정확히 같아야 하며 중앙 stop과 중복 실행하지 않는다.

```bash
REPO_ROOT='<REMOTE_REPO_FROM_CLUSTER_ENV>'
source "$REPO_ROOT/state/node.env"
cd /opt/approved/eugr-launcher
./launch-cluster.sh --no-ray \
  -n "$HEAD_FABRIC_IP,$PEER_FABRIC_IP" \
  --eth-if "$FABRIC_IFACE" --ib-if "$RDMA_HCA" \
  --name vllm-glm53-dflash2 stop
```

native lane으로 시작했을 때는 같은 중앙 stop 명령이 DGX-1, DGX-2 순서로 `stop-vllm-local.sh <CONTAINER_NAME>`을 실행한다. 어느 경로든 하네스가 두 rank container가 모두 사라졌는지 확인한 뒤에만 성공으로 반환한다. rank 하나만 남은 상태에서 모델을 전환하지 않는다.

## 9. GLM patch와 DFlash2 준비

GLM community repository archive를 풀지 않는다. 고정 commit에서 개별 검역된 top-k patch 파일만 `/opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py`에 배치하고, 두 노드에서 포털 승인 hash와 비교한다. upstream README, Dockerfile과 issue 분석은 별도 참고자료 문서에 두며 실행 디렉터리에 복사하지 않는다.

```bash
sha256sum /opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py
export GLM_PATCH_HOST_PATH=/opt/approved/glm53/sparse_attn_indexer_kpool_sm121.py
```

`glm53-nvfp4-acceptance.sh`와 `glm53-dflash2-operations.sh`는 이 파일이 없으면 fail closed한다. DFlash2 profile은 drafter config와 tree manifest도 검사한다. 시작 후 32K prompt + 100 token decode와 4시간 soak를 통과해야 운영 profile로 판정한다.

## 10. LiteLLM 시작

LiteLLM은 DGX-1에서 host network로 실행한다. config는 두 model alias를 가지지만 현재 실행 중인 vLLM의 served name만 성공한다. 중앙 SSH 하네스를 사용하면 secret은 DGX-1의 `REMOTE_LITELLM_ENV`에서만 읽고 stdout으로 출력하지 않는다.

```bash
./scripts/cluster-harness.sh configs/cluster.env gateway-start --apply
./scripts/cluster-harness.sh configs/cluster.env gateway-status
./scripts/cluster-harness.sh configs/cluster.env gateway-smoke ds4f-base
```

`gateway-start` 전에 DGX-1의 `REMOTE_LITELLM_ENV`를 mode `0600`으로 준비한다. API key를 문서, cluster config나 node.env에 저장하지 않는다. 관리 client는 LiteLLM `:4000`만 접근하고 vLLM `:8000`은 host firewall로 local 접근에 제한한다.

## 11. 재부팅과 서비스화

초기 acceptance가 끝나기 전 systemd auto-start를 만들지 않는다. 안정 profile과 stop/start 순서가 확정된 뒤 다음을 서비스로 고정한다.

1. network-online/RoCE
2. DGX-2 vLLM headless
3. DGX-1 vLLM head
4. DGX-1 LiteLLM

두 호스트 systemd 사이의 순서를 단일 unit dependency로 보장할 수 없으므로 health/retry timeout과 운영 runbook이 필요하다. 자동화 전에는 수동 시작을 기본으로 한다.
