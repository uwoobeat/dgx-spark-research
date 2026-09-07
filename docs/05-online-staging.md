# 온라인 staging 및 반입 신청

기준일: 2026-09-07 KST

## 원칙

인터넷 연결 staging 영역과 폐쇄망 설치 영역을 혼합하지 않는다. 인터넷에서 임의로 받은 파일을 매체에 직접 복사하지 않는다. OCI와 실행 필수 최소 파일은 검역 포털, 세 모델은 별도 모델 신청, 외부 GitHub repository 참고자료와 자체 작성 repository는 서로 구분된 별도 제출 경로를 사용한다. 모든 URL은 branch `main`이 아니라 revision/digest에 고정한다.

```text
upstream registry/raw.githubusercontent/PyPI -> digest·license manifest
  -> quarantine.yethangul.kr에 모델 없는 OCI와 실행 필수 개별 파일/wheel 등록
  -> 수집/SBOM/license/AV/vulnerability 검사와 승인 payload 수령

upstream Hugging Face -> revision·파일 목록만 사전 고정
  -> DS4F·GLM target·DFlash2 drafter를 모델별 별도 반입 신청(포털 미등록)
  -> 승인 절차로 snapshot 수집·파일별 SHA-256 생성

외부 GitHub repository의 전체 참고자료 -> repository별 고정 commit 목록
  -> 포털 SBOM 대상에서 제외하고 별도 문서 반입 절차

자체 작성 repository -> 반입 시점 공개 commit
  -> 외부 참고자료 묶음과 분리된 자체 repository 제출 절차

각 경로에서 승인된 payload
  -> 매체별 SHA256 manifest 작성·굽기·read-back 검증
  -> 폐쇄망 DGX에 복사·재검증
```

## 1. 로컬 인증정보

포털 계정은 저장소의 `.env`에만 있고 파일 모드는 `0600`이다. `.env`는 `.gitignore` 대상이며 Git, 문서, 화면 캡처, shell history에 값을 복사하지 않는다. `.env.example`만 공유한다.

CLI로 로그인·신청을 자동화하지 않는다. 2026-09-07 사용자 승인으로 `OCI 4 + RAW 6 = 10건`을 제출했고, 09:08:20 KST 확인 기준 회차 `3cd1d976-6339-48db-93f6-f0498f7c387f`이 `DOCKER linux/arm64` + `RAW raw-any`로 수집 중이다. API 응답은 `defaultedTypes=[]`, `status=RUNNING`, `artifactCount=0`이었다. 포털 신청과 별도 모델 신청은 서로 독립된 경로이며, 추가 회차·재시도·상태 변경은 목적, license와 manifest를 검토한 뒤 사람이 승인해 수행한다.

## 2. upstream identity 재확인

신청 직전에 [artifacts.lock.yaml](../manifests/artifacts.lock.yaml)의 값이 유효한지 확인하되, 자동으로 최신값으로 바꾸지 않는다.

```bash
docker buildx imagetools inspect '<IMAGE@sha256:PLATFORM_DIGEST>'
curl -fsSL 'https://huggingface.co/api/models/<ORG>/<MODEL>?blobs=true' | jq '{sha, siblings}'
git ls-remote '<REPO_URL>' '<PINNED_COMMIT>'
```

모델 repo의 현재 `sha`가 lock과 달라도 기존 revision URL이 접근 가능하면 lock을 유지한다. 새 revision이 필요한 경우 변경 사유와 새 크기/라이선스/파일 목록을 검토하고 별도 신청한다.

## 3. Hugging Face 모델 source inventory

온라인 staging host에서 모델별 TSV를 만든다.

```bash
./scripts/generate-hf-source-manifest.sh \
  deepseek-ai/DeepSeek-V4-Flash-0731 \
  7872f01b1d1fe23eabc4c98b48bffcef5a386062 \
  ds4f-base.raw.tsv

./scripts/generate-hf-source-manifest.sh \
  RedHatAI/GLM-5.3-Flash-NVFP4 \
  36c184c6cda000a481711306df5adde42f63321a \
  glm53-nvfp4.raw.tsv

./scripts/generate-hf-source-manifest.sh \
  incoai/GLM-5.3-Flash-DFlash2 \
  bf582e4eacc1810f76656d1811693ff6c6737d2a \
  glm53-dflash2-draft.raw.tsv
```

출력 열은 `path`, `bytes`, `upstream_lfs_sha256`, `over_5gb_decimal`, `url`이다. 세 inventory는 모두 포털 입력물이 아니며 별도 모델 신청 증빙이다. LFS payload는 Hub content SHA-256을 확인하고, 작은 Git 파일을 포함한 실제 수령 payload 전체에는 별도의 SHA-256 manifest를 만든다.

## 4. 모델 별도 반입 처리

DS4F, GLM target, DFlash2 drafter 세 모델은 크기와 무관하게 포털에 등록하지 않는다. [별도 모델 신청 목록](../manifests/separate-model-import.tsv)과 [작성 가이드](10-separate-model-import-application.md)를 사용한다.

1. 모델별 repo, immutable revision, 전체 bytes, license와 용도를 한 행으로 작성한다.
2. `manifests/models/*.raw.tsv`와 그 SHA-256을 source inventory 증빙으로 첨부한다.
3. 보안 담당자가 별도 반입 경로, 다운로드 주체, 허용 매체와 포장 방식을 승인한다.
4. 승인된 외부 staging에서 pinned revision 전체를 다운로드한다. Git LFS pointer가 아닌 실제 payload인지 확인한다.
5. `make-model-tree-manifest.sh`로 작은 Git 파일까지 포함한 모든 파일의 bytes·SHA-256을 생성한다.
6. 신청서의 payload manifest SHA 칸을 확정하고 승인된 payload만 매체에 기록한다.
7. 폐쇄망에서 파일별 manifest를 검증한 뒤 두 노드의 동일 경로로 배치한다.

파일 분할은 quarantine의 5 GB 제한 대응책이 아니다. 승인된 매체나 filesystem의 단일 파일 한계 때문에 담당자가 요구한 경우에만 다음 도구를 사용하고, 원본 SHA와 part SHA를 모두 별도 신청 증빙에 남긴다.

```bash
./scripts/split-large-file.sh model-00001-of-00010.safetensors ./parts
./scripts/reassemble-parts.sh \
  ./parts/model-00001-of-00010.safetensors.parts.tsv \
  ./reassembled/model-00001-of-00010.safetensors
```

분할 필요가 없으면 원본 directory tree를 보존한다. 확장자 변경, 포털 RAW 분할 등록, LFS pointer 반입은 금지한다.

## 5. OCI image 신청

Docker 또는 Crane 탭에서 OS `Linux`, arch `arm64`를 선택하고 [BOM](04-import-bom.md)의 platform manifest ref를 그대로 입력한다. 인증된 화면의 client는 full `image@sha256:digest`를 한 항목으로 인식했다. 실제 수집 전에 생성 화면에서 target summary가 `Linux · arm64`인지 다시 확인한다. 태그만 입력하면 이후 다른 image가 들어올 수 있다.

복사 가능한 목록:

- 필수: `manifests/quarantine-oci-required.txt`
- 조건부: `manifests/quarantine-oci-conditional.txt`

검증할 항목:

- resolved OS/architecture가 `linux/arm64`
- platform manifest digest가 lock과 일치
- image compressed size와 layer count
- image source와 사용 목적
- SBOM, CVE/AV 결과와 exception 사유
- community image의 Dockerfile/source commit 대응 관계

가능하면 조직 ARM64 builder에서 pinned official base와 검토된 patch를 재빌드하고 내부 registry digest를 신청한다. 그렇지 않으면 community prebuilt image를 immutable digest로 신청하고 포털이 만든 image SBOM과 별도 repository 출처 증빙을 함께 보존한다. OCI filesystem에 모델 snapshot/weight가 없다는 실물 검사는 `11-oci-model-content-audit.md`의 gate를 따른다.

## 6. 실행 필수 RAW와 외부 repository 참고자료

포털 RAW에는 [정본 목록](../manifests/quarantine-raw-sources.tsv)의 6개 행만 입력한다. GitHub 파일 URL은 `raw.githubusercontent.com/<owner>/<repo>/<40자리 commit>/<path>`로 고정하며, 이름·버전·한글 목적·license를 함께 복사한다. 수집 결과의 bytes와 SHA-256이 manifest와 다르면 반입을 중지한다.

eugr 4개 파일은 recipe 파싱·peer 확인·2노드 컨테이너 실행에 직접 필요하다. GLM top-k patch는 장문 실행 완화에 필요하고, PyYAML wheel은 외부 `pip` 접근을 없앤다. 이 최소 파일은 실행 payload이므로 포털 검사 대상이다.

전체 GitHub repository archive는 포털에 입력하지 않는다. 설계·출처·재빌드 참고자료는 [외부 repository 참고자료 제출안](12-external-repository-reference-submission.md)과 `manifests/external-repository-references.tsv`로 분리한다. 자체 작성 문서·스크립트가 들어 있는 이 repository도 그 외부 참고자료 bundle과 합치지 않고 반입 시점의 공개 commit을 별도 제출한다.

## 7. 매체 작성

승인 payload를 받은 뒤에만 실행한다.

```bash
./scripts/make-payload-manifest.sh /approved/payload payload-files.sha256
./scripts/verify-sha-manifest.sh /approved/payload payload-files.sha256
```

매체를 나눌 때 각 매체 root에 다음을 둔다.

- `MEDIA-ID.txt`
- 해당 매체 파일만 포함한 `media-NN.sha256`
- 전체 세트 목록 `MEDIA-SET.tsv`
- 재조립 절차의 인쇄본 또는 작은 README

굽기 직후 원본 staging 디렉터리가 아니라 실제 광매체 mount를 대상으로 SHA를 다시 검증한다. 매체 하나를 여분으로 만든다. 계정 `.env`는 매체에 넣지 않는다.

## 8. 포털 항목 공통 기재안

| 필드 | 내용 원칙 |
|---|---|
| 이름/버전 | 정확한 image digest 또는 개별 raw 파일의 source commit. 세 모델 revision은 별도 신청서에만 기재 |
| 목적 | “폐쇄망 DGX Spark ARM64 2노드 TP=2 LLM 추론”과 해당 component 역할 |
| license | upstream metadata와 license file 기준. 미표기는 `확인 필요`로 올리고 임의 추정 금지 |
| URL | revision/digest에 고정되고 검역 노드에서 접근 가능한 HTTPS |
| architecture | image/binary는 `linux/arm64` |
| 연관 항목 | runtime image ↔ patch/source ↔ LiteLLM 관계; 별도 신청한 model ID를 목적에 참조 |

M-02는 포털 항목이 아니라 별도 모델 신청 항목이며 [D-013](00-assumptions-and-decisions.md)에 따른 명시적 예외다. 신청 license는 MIT로 기재하되 자동 추정으로 기록하지 않고, checkpoint 미표기에 따른 `license_declared=NOASSERTION`과 원본 Z.AI MIT 및 2026-09-03 사용자 결정에 따른 `license_concluded=MIT`를 증빙에서 분리한다.

RAW 행의 실제 필드는 `URL`, `이름`, `버전`, `용도`, `라이선스`다. 버전과 라이선스는 비울 수 있지만 라이선스 공란은 `UNKNOWN`으로 처리된다. 회차 공통의 `반입 목적`은 최상위 항목과 하위 종속성에 상속된다. 완성된 신청 단위와 상태 전이는 [검역 포털 절차](08-quarantine-portal.md)를 따른다.

DS4F·GLM target·DFlash2 drafter의 URL, shard, config, tokenizer 또는 분할 part는 RAW로 입력하지 않는다. 모델에는 소형 예외를 두지 않는다. GitHub repository archive도 RAW로 우회 등록하지 않는다.
