# eugr 기반 DS4F·GLM 5.3 공통화 검토

기준일: 2026-09-03 KST

## 결론

`eugr/spark-vllm-docker`의 고정 commit에서 개별 검역한 no-Ray launcher 파일을 공통 오케스트레이션 계층으로 사용한다. 그러나 **B12X image 하나로 DS4F와 GLM 5.3 Flash를 모두 실행하지 않는다.** DS4F는 B12X, GLM은 tonyd2wild DFlash2 image를 선택하는 모델별 custom recipe를 사용하며, 본 저장소의 fail-closed launcher는 독립 검증·rollback 수단으로 유지한다. GitHub repository 전체 archive는 실행 반입물이 아니며, upstream 설명·Dockerfile·issue 자료는 별도 참고자료 문서에만 사용한다.

## 확인한 소스 상태

| 항목 | 고정값 | 확인 결과 |
|---|---|---|
| eugr repository | `e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e` | 2026-09-03 현재 HEAD. DS4F 0731 native recipe와 B12X build preset 존재 |
| eugr B12X vLLM fork | `local-inference-lab/vllm` `dev/infernal-invocation` @ `b5f995e73e6b7fe27c9927477e277a151ebcc9e9` | `vllm/models/glm5next`와 GLM 5.3 등록이 없음 |
| vLLM GLM PR | #53906 @ `8f8cc414d1c7648aad8808ba94e7c7fb1b6a72c2` | 94 files 변경, 기준일 open |
| GLM community image | `sm121-v11-dflash2` platform digest `sha256:4def0ef…` | DFlash2 운영 image. `sm121-v8`은 non-DFlash2 rollback이며 둘 다 eugr B12X 기반이 아님 |

eugr `deepseek-v4-flash-0731.yaml`은 `vllm-node-b12x`, B12X sparse MLA/MoE/linear backend, InstantTensor, DSpark speculation을 명시한다. 반면 저장소에는 GLM 5.3 recipe가 없으며 GLM 계열은 4.7 또는 8-node GLM 5.2 recipe만 있다.

## 단일 B12X image 시험 결과

eugr Dockerfile이 사용하는 것과 같은 방식으로 B12X fork HEAD에 vLLM PR #53906의 merge-base diff를 `git apply --3way --index`로 모의 적용했다.

- PR merge base: `f870b9297685bd3c968063b52b769315cb08fd7f`
- B12X target: `b5f995e73e6b7fe27c9927477e277a151ebcc9e9`
- 결과: conflict
- code conflict 예: `vllm/config/vllm.py`, model registry, MLA/indexer, KV cache, worker와 utility code

eugr Dockerfile은 tests/docs conflict만 무시하고 code conflict는 build failure로 처리한다. 따라서 `./build-and-copy.sh --exp-b12x --apply-vllm-pr 53906`은 현 소스 조합에서 자동 통합 경로가 아니다. 충돌을 수동 해결해도 GLM용 NoPE MLA, FlashInfer 0.6.18, NCCL 2.30.7 재고정, Cutlass DSL 4.6.2 재고정, PDL 제한, indexer와 fp8 KV patch를 다시 포팅·검증해야 한다.

## 선택지 비교

| 경로 | DS4F | GLM 5.3 | 반입·운영 판단 |
|---|---|---|---|
| eugr B12X image 하나 | native recipe | 구현 부재, PR 충돌 | 배제 |
| eugr launcher + 모델별 image | native B12X | 외부 DFlash2 image, drafter, patch mount | **채택; 실장비 acceptance 조건** |
| eugr upstream-main 자체 build + GLM patch chain | 별도 DS4F 성능 재검증 필요 | 포팅 가능성은 있으나 미검증 | 내부 ARM64 builder가 있을 때 연구 과제 |
| 본 저장소 launcher + 모델별 digest | profile로 고정 | image ID와 patch/drafter SHA fail-closed | 독립 검증·rollback |

## eugr launcher 적용 방식

eugr를 launcher로 쓴다는 것은 eugr image 하나를 강제한다는 뜻이 아니다. `run-recipe.py`가 custom YAML을 읽고 `launch-cluster.sh`에 선택한 image와 command를 넘기면, launcher가 두 노드에 동일 image·volume을 가진 idle container를 만든 뒤 worker rank 1을 먼저 `docker exec`, head rank 0을 나중에 실행한다. no-Ray 모드에서는 다음 인자를 자동 추가한다.

- 두 rank 공통: `--nnodes 2 --master-addr <HEAD> --master-port <PORT>`
- worker: `--node-rank 1 --headless`
- head: `--node-rank 0`

따라서 recipe에는 위 인자와 `--distributed-executor-backend`를 넣지 않는다. GLM 커널·vLLM 구현은 tonyd2wild image가 제공하며 eugr는 이를 바꾸지 않는다.

폐쇄망 runtime은 repository checkout이 아니라 다음 개별 승인 파일로 조립한다.

| 파일 | 필요 이유 |
|---|---|
| `run-recipe.sh` | local PyYAML 환경에서 recipe runner 호출 |
| `run-recipe.py` | 본 저장소의 offline custom YAML을 launch command로 변환 |
| `launch-cluster.sh` | 두 노드 container, worker-first rank와 rendezvous 실행 |
| `autodiscover.sh` | `launch-cluster.sh`가 source하는 필수 동반 파일; 운영값은 명시적으로 주입 |

각 실행 파일은 commit 고정 `raw.githubusercontent.com` URL, SHA-256, license 선언과 포털 산출물/SBOM을 따로 보존한다. root `LICENSE` 원문은 [외부 repository 참고자료](12-external-repository-reference-submission.md)의 별도 문서 증빙으로 관리하며 실행 RAW 항목에 섞지 않는다. 승인된 4개 실행 파일만 `/opt/approved/eugr-launcher`에 배치하고, 전체 tree를 받은 repository처럼 취급하거나 `git` 명령을 실행하지 않는다. `build-and-copy.sh`, `hf-download.sh`, upstream recipe/문서는 내부 실행에 사용하지 않는다.

적용 및 acceptance 조건은 다음과 같다.

1. eugr 개별 launcher 파일의 commit, SHA-256, MIT license와 포털 산출물을 확인한다.
2. download/build 기능을 사용하지 않고 승인된 local image alias와 local model path만 사용한다.
3. 명시적 node list, fabric NIC/HCA, `--no-ray`, worker-first 실행을 사용한다.
4. DS4F는 `configs/eugr-recipes/ds4f-base-offline.yaml`과 승인된 local model mount를 사용한다.
5. GLM은 `configs/eugr-recipes/glm53-dflash2-offline.yaml`, `sm121-v11-dflash2`, target/drafter/cache/top-k patch의 read-only mount를 사용한다.
6. GLM recipe에는 `--kv-cache-memory`를 넣지 않고 profiler sizing을 사용하며, 기본 동시성은 1이다.
7. 두 경로 모두 외부 DNS/HTTP 시도가 0이고, 두 노드 image config digest·model tree·patch SHA가 일치하는지 확인한다.
8. eugr container는 vLLM이 `docker exec` 자식으로 죽어도 keepalive container가 남을 수 있으므로 `/health`와 vLLM process를 함께 감시한다.
9. eugr는 worker command를 먼저 dispatch하지만 tonyd2wild 수동 launcher의 고정 `sleep 25`는 넣지 않는다. 분산 rendezvous가 양 rank를 기다리는 것이 정상이나, 반복 cold boot에서 startup race가 없는지 실장비로 확인한다.
10. API/32K decode/4시간 soak/rollback gate를 통과해야 운영 승인한다.

eugr의 runtime patch/mod 기능은 online download나 container 내부 변경을 수행할 수 있다. 폐쇄망 acceptance에서는 runtime mutation을 금지하고, 필요한 변경은 새 OCI digest로 빌드·검역한다. upstream repository의 참고 코드는 별도 문서 검토에만 쓰며 승인된 개별 실행 파일을 현장에서 임의 수정하지 않는다.

## 향후 단일 image 재검토 조건

다음이 모두 충족되면 새 image를 별도 후보로 만들 수 있다.

- GLM PR이 merge되거나, 양쪽 fork 사이의 code conflict가 검토 가능한 내부 commit으로 해소됨
- GLM community patch chain이 새 소스 shape에 맞게 fail-closed 방식으로 포팅됨
- DS4F B12X와 GLM NoPE MLA가 같은 dependency pin에서 각각 통과함
- ARM64 image SBOM·license·CVE 검토 및 immutable platform/config digest 확보
- DS4F base와 GLM NVFP4의 전체 acceptance를 같은 image로 반복 통과

한 모델만 통과한 통합 image는 다른 모델의 대체 runtime으로 승격하지 않는다.
