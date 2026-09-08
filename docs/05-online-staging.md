# 온라인 staging 및 반입 신청

기준일: 2026-09-07 KST

## 원칙

인터넷 연결 staging과 폐쇄망 설치를 분리한다. 포털은 코드·wheel 6건 회차와 repository 소스 8건 회차만 사용한다. 모든 OCI와 모델은 수동 반입하며 버전·digest를 고정한다.

노선: 원본 코드·wheel → 포털 회차 A / GitHub source ZIP → 포털 회차 B / 모델·모든 OCI → 수동 수집·검사·승인 → 매체 검증.


## 1. 로컬 인증정보

포털 URL과 계정은 저장소의 `.env`에 `QUARANTINE_*` 변수로만 두고 파일 모드는 `0600`으로 유지한다. `.env`는 `.gitignore` 대상이며 Git, 문서, 화면 캡처, shell history에 값을 복사하지 않는다. placeholder만 있는 `.env.example`만 공유한다.

CLI로 로그인·신청을 자동화하지 않는다. 포털은 코드·wheel RAW 6건과 repository RAW 8건을 두 회차로 분리하며 OCI가 없는지 생성 전후 확인한다. 모델 3개와 OCI 4개는 별도 수동 반입 경로이며, 제출·재시도·상태 변경은 목적, license와 manifest를 검토한 뒤 승인된 절차로 수행한다. 실제 회차 식별자·시각·상태와 처리 이력은 `state/` 또는 조직이 지정한 비공개 기록에만 둔다.

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

파일 분할은 공통 OCI/RAW 포털의 파일 크기 제한을 우회하는 수단이 아니다. 승인된 매체나 filesystem의 단일 파일 한계 때문에 담당자가 요구한 경우에만 다음 도구를 사용하고, 원본 SHA와 part SHA를 모두 별도 신청 증빙에 남긴다.

```bash
./scripts/split-large-file.sh model-00001-of-00010.safetensors ./parts
./scripts/reassemble-parts.sh \
  ./parts/model-00001-of-00010.safetensors.parts.tsv \
  ./reassembled/model-00001-of-00010.safetensors
```

분할 필요가 없으면 원본 directory tree를 보존한다. 확장자 변경, 포털 RAW 분할 등록, LFS pointer 반입은 금지한다.

## 5. OCI image 수동 반입

[필수 4개 목록](../manifests/manual-oci-import.txt)의 고정 platform digest로 온라인 staging에서 image 전체를 수집한다. Docker/crane 포털 입력에는 넣지 않는다. [조건부 목록](../manifests/manual-oci-conditional.txt)은 별도 채택 승인 전까지 수집 대상이 아니다.

폐쇄망에서 load 가능한 archive를 만들고 실제 크기·SHA-256을 기록한다. `artifacts.lock.yaml`과 OS/architecture(`linux/arm64`), platform digest, config digest를 대조한다. 각 image의 SBOM·license·CVE/AV·모델 미포함 검사 증빙은 수동 반입 승인에 포함한다. 과거 포털 수집 성공은 이 검증을 면제하지 않는다.

## 6. 실행 필수 RAW와 외부 repository 참고자료

포털 RAW에는 [정본 목록](../manifests/quarantine-raw-sources.tsv)의 6개 행만 입력한다. GitHub 파일 URL은 `raw.githubusercontent.com/<owner>/<repo>/<40자리 commit>/<path>`로 고정하며, 이름·버전·한글 목적·license를 함께 복사한다. 수집 결과의 bytes와 SHA-256이 manifest와 다르면 반입을 중지한다.

eugr 4개 파일은 recipe 파싱·peer 확인·2노드 컨테이너 실행에 직접 필요하다. GLM top-k patch는 장문 실행 완화에 필요하고, PyYAML wheel은 외부 `pip` 접근을 없앤다. 이 최소 파일은 실행 payload이므로 포털 검사 대상이다.

전체 GitHub repository archive는 소스코드 전용 포털 회차에 입력한다. 설계·출처·재빌드 참고자료는 [외부 repository 참고자료 제출안](12-external-repository-reference-submission.md)과 `manifests/external-repository-references.tsv`로 분리한다. 자체 작성 문서·스크립트가 들어 있는 이 repository는 같은 소스코드 회차의 S-01로 제출하되 외부 upstream과 별도 행·provenance를 유지한다.

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

RAW 행에는 최소한 고정 URL, 이름, 버전, 용도와 license 판단을 제공한다. 필수 여부와 공란 처리 방식은 제출 시 승인된 양식에서 확인한다. 공개 절차는 [검역 포털 절차](08-quarantine-portal.md)를 따르며 제품별 상태 전이와 실제 실행 결과는 비공개 기록에서 관리한다.

DS4F·GLM target·DFlash2 drafter의 URL, shard, config, tokenizer 또는 분할 part는 RAW로 입력하지 않는다. 모델에는 소형 예외를 두지 않는다. GitHub repository archive도 RAW로 우회 등록하지 않는다.
