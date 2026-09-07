# OCI image 모델 비포함 감사

기준일: 2026-09-03 (KST)

## 결론과 현재 gate

포털에 신청할 네 runtime image는 **모델 checkpoint/snapshot을 넣지 않은 image**로 취급한다. 2026-09-03의 외부망 사전감사는 다음 근거를 모두 통과했다.

- 고정된 `linux/arm64` manifest와 config digest를 확인했다.
- OCI config build history에 Hugging Face snapshot download, `git lfs`, `from_pretrained`, `model.safetensors`, GGUF 또는 PyTorch checkpoint를 image에 넣는 명령이 없었다.
- 공개된 고정 source의 Dockerfile은 runtime·kernel·patch·Python code를 넣지만 모델 weight를 `COPY`/`ADD`하지 않는다.
- image 압축 layer 크기와 모델 snapshot 크기가 양립하지 않으며, 특히 DFlash2 overlay 증분은 drafter snapshot보다 약 96배 작다.
- 실제 운영 recipe는 host의 별도 모델 디렉터리를 read-only bind mount한다.

단, config/history와 source 검토만으로 opaque base layer의 실제 파일을 완전히 증명할 수는 없다. 따라서 상태는 다음처럼 분리한다.

| gate | 상태 | 의미 |
|---|---|---|
| 외부망 manifest/config/history/source 사전감사 | **PASS** | 검역 신청 후보로 유지 가능 |
| 검역 산출물별 SBOM과 digest 결속 확인 | **PENDING** | repository SBOM이 아니라 image별 SBOM이어야 함 |
| 승인 후 load한 실물의 전체 layer 및 merged filesystem 검사 | **PENDING** | 이 단계가 PASS하기 전에는 CD 적재·폐쇄망 반입 불가 |

실물 검사에서 하나라도 signature가 검출되거나, scan 자체가 완주하지 못하거나, SBOM의 대상 digest가 아래 표와 다르면 **fail closed**한다. 예외 목록으로 우회하지 않고 해당 image를 반입 대상에서 제거한 뒤 모델 없는 image로 교체한다.

## 감사 대상과 immutable identity

아래 값은 2026-09-03에 registry manifest를 read-only 조회하여 다시 확인했으며 `manifests/artifacts.lock.yaml`과 일치한다. 압축 크기는 platform manifest의 layer `size` 합계다.

| 용도 | immutable image ref | config digest | platform | 압축 layer 합계 | layer 수 |
|---|---|---|---|---:|---:|
| DS4F B12X runtime | `docker.io/eugr/spark-vllm-b12x@sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd` | `sha256:f89e9baedf38ffe3165641d4a937b59b227bbbd58d0116a7518c53b97d601823` | `linux/arm64` | 11,313,467,484 B | 21 |
| GLM DFlash2 runtime | `ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:4def0ef644cb2e9814136dcffd5e385e21bc594f48f3b292234051904abe85a6` | `sha256:35c6f70ffcba62fd67d7b9d4b4e8300ad177201792ce9cdb1ea18fd449bc23b6` | `linux/arm64` | 14,204,524,092 B | 48 |
| GLM v8 rollback runtime | `ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:d77d375c742fc54f436dec5108b440f58f021bc6600052bf0e8fe5840357e78f` | `sha256:08e3703a018ecac5150c1c756d92711e10af808a5c2bb9377088ff9db43967f2` | `linux/arm64` | 14,180,175,179 B | 41 |
| LiteLLM gateway | `ghcr.io/berriai/litellm@sha256:2d0f10790c6d9a72f240465ebe755987c40bdd0795cba9f57cbebc7ddc6e5c6f` | `sha256:69dff3ddc51c4cf4f799d1ddddaca304bf94cfe0f3b357d596de0670baa3b3d1` | `linux/arm64` | 385,624,109 B | 21 |

멀티아키텍처 tag나 index digest가 아니라 위 ARM64 platform manifest digest를 검역·SBOM·실물 검사 전체에서 동일하게 사용한다.

## image별 근거

### eugr B12X

- 고정 source: [`eugr/spark-vllm-docker` Dockerfile @ `e9cf3596`](https://github.com/eugr/spark-vllm-docker/blob/e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e/Dockerfile)
- Dockerfile의 runtime 산출물은 CUDA/NCCL, vLLM/FlashInfer/B12X wheel, patch 및 build metadata다. 모델 snapshot download나 모델 파일 `COPY`/`ADD`가 없다. `fastsafetensors`와 `instanttensor`는 weight가 아니라 loader package다.
- immutable config history도 동일한 범주의 설치·복사만 보이며 모델 download/copy signature는 0건이었다.
- image의 압축 layer 합계 11.31 GB는 별도 신청할 DS4F snapshot 166,898,661,074 B를 담을 수 없다. 이는 단독 증명이 아니라 Dockerfile/history 증거를 보강하는 크기 검산이다.

### tonyd2wild GLM v8와 v11 DFlash2

- 고정 source: [`tonyd2wild` repository @ `050081dc`](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark/tree/050081dc41ce6edd4d3f15fa19dc3410ba4210e3)
- [`sm121-v8` Dockerfile](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark/blob/050081dc41ce6edd4d3f15fa19dc3410ba4210e3/docker/Dockerfile.glm53-sm121-v8)는 v7 위에 `patch_v8_fp8.py`만 복사·적용한다.
- [`DFlash2` overlay Dockerfile](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark/blob/050081dc41ce6edd4d3f15fa19dc3410ba4210e3/overlay-dflash2/Dockerfile)은 `qwen3_dflash2.py`, `dflash2/` 구현 code와 네 patch script만 복사한다.
- 작성자 README도 [published image에는 vLLM과 patch만 있고 weight는 runtime bind mount한다고 명시](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark/blob/050081dc41ce6edd4d3f15fa19dc3410ba4210e3/README.md#L47-L67)한다. 이는 community 작성자의 주장이고 실물 scan을 대체하지 않는다.
- v11 DFlash2와 v8의 압축 layer 차이는 `14,204,524,092 - 14,180,175,179 = 24,348,913 B`다. DFlash2 drafter snapshot은 5개 파일, 총 `2,342,460,697 B`이고 그중 `model.safetensors`가 `2,342,169,800 B`다. overlay 증분은 전체 drafter보다 약 `96.20×` 작으므로 drafter checkpoint가 overlay에 들어 있지 않다.
- GLM target snapshot도 197,881,157,135 B로 두 runtime image보다 훨씬 크며, history에 target download/copy도 없다.

### LiteLLM

- immutable config history는 `/app/.venv`, proxy/Docker code, Prisma schema·migration 및 enterprise code를 복사한다. 모델 download/copy signature는 0건이었다.
- 압축 layer 합계가 385,624,109 B로 DS4F, GLM target뿐 아니라 2,342,460,697 B DFlash2 drafter도 포함할 수 없다.
- LiteLLM은 API gateway이며 model path를 받지 않는다. model checkpoint를 넣을 운영상 이유도 없다. 이 추론 역시 실물 scan과 SBOM으로 최종 확인한다.

## DFlash2 code와 model weight의 구분

다음 두 항목을 혼동하면 안 된다.

| 구분 | 위치/내용 | 반입 경로 |
|---|---|---|
| DFlash2 구현 code | image 안의 `qwen3_dflash2.py`, `vllm/.../spec_decode/dflash2/`, registry/KV patch | runtime OCI image, image SBOM 대상 |
| DFlash2 drafter model | 별도 snapshot의 `config.json`, tokenizer/config 자료 및 `model.safetensors` | 모델 별도 반입 신청서; 포털 OCI/RAW 대상 아님 |

즉 image history에 `DFlash2DraftModel`이라는 class 이름이나 `dflash2/` code directory가 보이는 것은 모델 weight 포함 증거가 아니다. 반대로 `model.safetensors`, Hugging Face snapshot/cache tree 또는 checkpoint 파일은 발견 즉시 차단 대상이다.

## runtime bind mount 근거

저장소의 오프라인 recipe와 배포 가이드는 image 내부 경로가 아니라 별도 반입한 host model tree를 사용한다.

```text
/srv/models/DeepSeek-V4-Flash-0731   -> /models/ds4f:ro
/srv/models/GLM-5.3-Flash-NVFP4     -> /models/glm53:ro
/srv/models/GLM-5.3-Flash-DFlash2   -> /models/dflash2-draft:ro
```

DS4F는 `vllm serve /models/ds4f`, GLM은 `vllm serve /models/glm53`와 `model=/models/dflash2-draft`로 시작한다. `HF_HUB_OFFLINE=1` 및 `TRANSFORMERS_OFFLINE=1`도 설정하므로 runtime이 외부 Hub에서 모델을 보충한다는 가정은 없다.

## 검역 산출물 SBOM 및 실물 검사 절차

GitHub repository 자체를 검역 포털 항목으로 올리거나 repository에 대해 형식적인 SBOM을 만들지 않는다. 위 source URL은 외부망 조사 증거일 뿐이다. 검역 대상은 네 OCI image이고, 각 image의 SBOM은 해당 immutable ARM64 manifest/config digest와 1:1로 결속되어야 한다. 외부 repository 참고자료는 별도 문서 반입 절차, 이 저장소의 자체 runbook·script는 저장소 자체의 별도 반입 절차를 따른다.

승인된 OCI archive를 스테이징 Docker에 load한 뒤 아래 명령을 각 image에 실행한다. stdout/stderr를 image별 감사 로그로 보존하고 로그 자체의 SHA-256도 매체 manifest에 기록한다.

```bash
sudo ./scripts/audit-loaded-image-no-models.sh \
  'docker.io/eugr/spark-vllm-b12x@sha256:7dc02f162929943ba2e14514066ed2a04bb7e9ed3592d4eb460ebcbb1f8376bd' \
  'sha256:f89e9baedf38ffe3165641d4a937b59b227bbbd58d0116a7518c53b97d601823'

sudo ./scripts/audit-loaded-image-no-models.sh \
  'ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:4def0ef644cb2e9814136dcffd5e385e21bc594f48f3b292234051904abe85a6' \
  'sha256:35c6f70ffcba62fd67d7b9d4b4e8300ad177201792ce9cdb1ea18fd449bc23b6'

sudo ./scripts/audit-loaded-image-no-models.sh \
  'ghcr.io/tonyd2wild/vllm-glm53-flash@sha256:d77d375c742fc54f436dec5108b440f58f021bc6600052bf0e8fe5840357e78f' \
  'sha256:08e3703a018ecac5150c1c756d92711e10af808a5c2bb9377088ff9db43967f2'

sudo ./scripts/audit-loaded-image-no-models.sh \
  'ghcr.io/berriai/litellm@sha256:2d0f10790c6d9a72f240465ebe755987c40bdd0795cba9f57cbebc7ddc6e5c6f' \
  'sha256:69dff3ddc51c4cf4f799d1ddddaca304bf94cfe0f3b357d596de0670baa3b3d1'
```

검사기는 다음 조건을 모두 강제한다.

1. 입력 image ref가 immutable digest 형식이다.
2. load된 image가 `linux/arm64`이고 config digest가 고정값과 같다.
3. 선언된 Docker volume이 없어 merged filesystem scan에서 가려지는 경로가 없다.
4. `docker image save` stream의 모든 layer payload를 검사하여 후속 whiteout으로 삭제된 weight도 찾는다.
5. `docker export` stream의 최종 merged filesystem을 다시 검사한다.
6. 대상 모델명, Hugging Face/ModelScope/Torch checkpoint cache, top-level model/weight/checkpoint directory, 일반 checkpoint 확장자와 shard naming을 하나라도 찾으면 실패한다.

SBOM은 package/license/CVE inventory 증거이고, 위 검사는 모델 payload filename/path 증거다. 어느 하나도 다른 하나를 대체하지 않는다. SBOM에 embedded model 또는 출처 불명 대형 data package가 나타나거나 scanner가 실패하면 해당 image는 반입하지 않는다.

## 한계

- 외부망 사전감사에서는 약 40 GB의 네 image를 모두 pull하지 않았다. 현재 시스템의 디스크 한계 때문에 registry manifest/config/history만 read-only 확인했다.
- filename/path scan은 암호화·난독화되거나 비표준 이름으로 포장된 payload의 의미까지 판별할 수 없다. 그래서 source/history, size 검산, image SBOM, 전체 layer scan을 결합한다.
- community image의 build provenance와 repository license가 완전하다는 뜻은 아니다. 본 문서는 오직 모델 checkpoint/snapshot 비포함 여부의 gate를 정의한다.
