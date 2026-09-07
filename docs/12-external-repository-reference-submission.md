# 외부 repository 참고자료 별도 제출

기준일: 2026-09-03 KST

## 범위와 경계

이 문서는 GitHub의 **외부 upstream repository 전체 자료**를 설계 검토, 출처 추적, 장애 분석, 필요 시 재빌드에 참고하기 위한 별도 제출 목록이다. repository archive는 `quarantine.yethangul.kr`에 등록하지 않으며 포털 SBOM 생성·비교 단위로 취급하지 않는다.

다음 세 묶음과 명확히 분리한다.

- 포털 OCI/RAW: 모델이 없는 runtime image 4개와 실행 필수 개별 파일 5개, PyYAML wheel 1개
- 모델 별도 신청: DS4F, GLM target, DFlash2 drafter snapshot 각 1행
- 자체 작성 repository: 설치·운영 harness와 문서를 포함한 이 repository의 반입 시점 공개 commit; 외부 upstream 참고자료 bundle에 넣지 않음

## 제출 대상

기계 판독 정본은 [external-repository-references.tsv](../manifests/external-repository-references.tsv)다.
manifest의 `item_id`를 변경하지 않는 stable ID와 로컬 디렉터리 이름으로 사용한다.

| ID | repository@pin | 목적 | license 상태 | 포털 RAW와 겹치는 최소 파일 |
|---|---|---|---|---|
| E-01 | `eugr/spark-vllm-docker@e9cf3596c…f86e` | DS4F recipe와 2노드 launcher 설계·출처 | MIT | 실행 파일 4개 |
| E-02 | `local-inference-lab/vllm@b5f995e7…9e9` | B12X image의 vLLM fork 계보·재빌드 | Apache-2.0 | 없음 |
| E-03 | `tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark@050081dc…0e3` | GLM image·patch·장애 분석 | root `NOASSERTION` | top-k patch 1개 |
| E-04 | `NVIDIA/dgx-spark-playbooks@34739033…bfc` | NVIDIA DGX Spark network·멀티노드 절차 | Apache-2.0 + third-party notices | 없음 |
| E-05 | `vllm-project/vllm@8f8cc414…a2c2` | GLM 5.3 PR #53906 미병합 구현 | Apache-2.0 | 없음 |
| E-06 | `vllm-project/vllm@402ad454…5a16` | DeepSeek V4 SM121 PR #53055 fallback | Apache-2.0 | 없음 |
| E-07 | `BerriAI/litellm@10f40334…fc52` | LiteLLM v1.99.1 gateway source·설정·장애 분석 | MIT, `enterprise/` 별도 commercial license | 없음 |

포털에 등록된 E-01/E-03의 최소 raw 파일은 실제 실행 payload다. 같은 파일이 외부 repository 참고자료에도 존재하더라도 포털 승인 결과와 repository 참고자료 승인 결과를 서로 대체하지 않는다.

### 현재 링크 모음의 충족 범위

현재 manifest에는 기존에 요청된 외부 GitHub repository 6개와 누락됐던 LiteLLM upstream을 합친 **7개**의 URL과 40자리 pin이 있다. 이 목록은 eugr launcher/recipe, B12X vLLM fork, GLM DFlash2 wrapper, NVIDIA 멀티노드 playbook, GLM·DeepSeek 관련 vLLM PR code tree, LiteLLM gateway source를 오프라인에서 추적한다. 동일한 `vllm-project/vllm`도 서로 다른 PR head를 재현해야 하므로 E-05와 E-06으로 분리한다.

LiteLLM E-07은 공식 GitHub의 `refs/tags/v1.99.1`이 직접 가리키는 commit `10f4033437df30b91b5dbf2b64711d0a8683fc52`로 고정했다. 공식 release는 2026-09-02에 게시됐다. root `LICENSE`는 `enterprise/` 외 영역을 MIT로 두고 enterprise 영역은 별도 license를 적용하므로 단순 `MIT`로 축약하지 않는다.

Primary source:

- `https://github.com/BerriAI/litellm/releases/tag/v1.99.1`
- `https://github.com/BerriAI/litellm/commit/10f4033437df30b91b5dbf2b64711d0a8683fc52`
- `https://github.com/BerriAI/litellm/blob/10f4033437df30b91b5dbf2b64711d0a8683fc52/LICENSE`

Repository 목록은 이제 실행 stack의 핵심 source를 포함하지만, Git clone/archive에는 GitHub PR·Issue 본문과 댓글이 들어오지 않는다. 이 공백은 아래 정적 웹 캡처 목록으로 별도 관리한다.

## GitHub PR·Issue 정적 캡처 목록

기계 판독 정본은 [external-web-references.tsv](../manifests/external-web-references.tsv)다. `docs/source-ledger.md`의 핵심 운영 근거와 대조한 결과, 우선 보존 대상 5개가 모두 포함됐다.

| ID | 고정 식별자 | 대상 | 보존 목적 |
|---|---|---|---|
| W-01 | `I_kwDOQc-I788AAAABM5JAbg` | eugr issue #349 | B12X CUDA graph regression·rollback |
| W-02 | `I_kwDOQc-I788AAAABN72kUQ` | eugr issue #358 | 장시간 acceptance 저하·speculation gate |
| W-03 | `I_kwDOUFWOp88AAAABO7ItQg` | tonyd2wild issue #14 | GLM 장문 동시 요청 저하·완화 |
| W-04 | `PR_kwDOI7xefs8AAAABBFit-A` | vLLM PR #53906, head `8f8cc414…a2c2` | GLM 구현 설명·리뷰·미병합 상태 |
| W-05 | `PR_kwDOI7xefs8AAAABAX8oFg` | vLLM PR #53055, head `402ad454…5a16` | DeepSeek SM121 fallback 설명·리뷰·상태 |

GitHub node ID와 PR head commit은 대상을 식별하지만 페이지 내용 전체를 불변으로 만들지는 않는다. 승인된 캡처 시점에 HTML과 GitHub API JSON을 페이지네이션 끝까지 저장하고 각 파일 SHA-256 및 전체 package SHA-256을 계산한 후 manifest의 `PENDING_AFTER_APPROVED_CAPTURE`를 실측값으로 교체한다. Issue는 본문 JSON과 comments JSON, PR은 pull JSON·issue comments·review comments·reviews JSON을 포함한다. 캡처 시각, 응답 URL, page 번호, 확인된 `updated_at`도 companion inventory에 기록한다.

이 5개는 OCI/RAW와 repository archive 어느 쪽도 아니다. `quarantine.yethangul.kr`에 등록하거나 SBOM 대상으로 꾸미지 않고 `separate-external-web-reference-document-submission` 경로로 제출한다. 현재 단계에서는 URL·식별자·용도·route만 정리했으며 실제 페이지 payload를 다운로드하지 않았다.

## 별도 제출 패키지

조직의 repository 반입 양식이 확정되면 repository마다 다음을 하나의 증빙 단위로 묶는다.

1. repository URL, 40자리 commit, 확인일, 목적
2. 해당 commit의 파일 목록과 수집 후 전체 archive SHA-256
3. root LICENSE, NOTICE, third-party notice와 license 미표기 판단서
4. 실행에 직접 사용하는 파일과 단순 참고자료의 구분표
5. 원문 README/Dockerfile/patch와 이 repository에서 작성한 해설 문서의 구분표
6. 별도 반입 승인번호와 수령·매체 read-back SHA 검증 결과

승인 전에는 mutable branch archive나 `main`의 ZIP을 최종 payload로 채택하지 않는다. 제출 담당자가 허용한 형식으로 commit 고정 archive 또는 bundle을 만든 뒤 실제 파일 SHA-256을 확정한다. 포털에서 생성되지 않은 repository SBOM을 임의로 포털 SBOM처럼 표시하거나 비교 결과로 사용하지 않는다.

repository는 OCI가 아니며 이 경로에서 SBOM 생성·비교 대상이라고 가정하지 않는다. 제출 증빙의 archive SHA-256, 아래 파일 트리 manifest, license 검토 기록은 repository 무결성과 provenance를 위한 것이고 포털 SBOM을 모사하거나 대체하지 않는다.

## 폐쇄망 배치 구조

승인된 archive 또는 Git bundle만 자체 repository의 다음 ignored 경로에 푼다.

```text
third_party/
  README.md                         # 이 public repository가 추적하는 규약
  upstreams/                        # .gitignore 대상; 외부 원문
    E-01/                           # manifest item_id가 stable ID
    E-02/
    E-03/
    E-04/
    E-05/
    E-06/
    E-07/
```

외부 원문은 `third_party/upstreams/<item_id>/` 아래에서 read-only로 취급한다. 이 저장소의 public commit에는 `third_party/README.md`만 포함하고 upstream 파일, Git object, 제출 archive, checksum sidecar를 commit하지 않는다. E-05/E-06처럼 repository URL이 같아도 pin이 다르면 디렉터리를 합치지 않는다.

각 디렉터리에는 수집·제출 단계에서 다음 로컬 metadata를 둔다. 이 파일들은 upstream 원문이 아니라 반입 provenance이며 파일 트리 manifest 계산에서 제외한다.

| 파일 | 규칙 |
|---|---|
| `.source-url` | manifest의 repository URL과 정확히 일치 |
| `.source-commit` | `.git`이 없는 commit archive에 필수; manifest의 40자리 pin과 정확히 일치 |
| `.source-tree.sha256` | `F/L<TAB>SHA-256<TAB>상대경로` 형식의 정렬된 전체 파일·symlink manifest |
| `.source-tree.sha256.digest` | 위 manifest 자체의 SHA-256 한 줄 |
| `.license-review.txt` | license가 `NOASSERTION`인 E-03에 필수인 별도 검토·승인 기록; upstream license로 표시하지 않음 |

Git metadata가 있으면 검증기는 `HEAD`가 pin과 같은지, tracked 파일이 수정되지 않았는지 확인한다. Git metadata가 없는 archive는 `.source-commit`과 별도 제출서에 기록된 archive SHA-256을 함께 사용한다. `.source-commit`만으로 archive가 실제 해당 commit에서 왔다는 암호학적 증명이 되지는 않으므로 제출 archive/media checksum 확인을 생략하지 않는다.

## 수집 후 오프라인 검증 gate

현재 외부망 조사 단계에서는 upstream을 다운로드하거나 위 경로를 채우지 않는다. repository 별도 반입 승인 후 외부 스테이징에서 고정 commit을 수집하고 `.source-url` 및 archive 방식이면 `.source-commit`을 기록한 다음, 명시적 수집 승인 상태에서 tree manifest를 만든다.

```bash
# 온라인 스테이징 호스트; 승인된 E-01을 배치한 뒤, 네트워크/SSH를 쓰지 않는 로컬 명령
DGX_AGENT_MODE=external REPOSITORY_REFERENCE_COLLECTION_APPROVED=yes \
  ./scripts/verify-offline-repositories.sh --write-manifest E-01

# 폐쇄망 반입 직후; manifest의 일곱 디렉터리가 모두 있어야 하며 원문을 변경하지 않음
./scripts/verify-offline-repositories.sh --require-all
```

첫 명령이 만든 `.source-tree.sha256.digest` 값과 repository archive SHA-256을 별도 반입 신청서 및 매체 manifest에 옮겨 사람이 대조한다. 두 번째 명령은 인터넷, SSH, `git fetch`를 사용하지 않으며 다음 중 하나라도 발생하면 실패한다.

- stable ID 디렉터리 누락, URL/pin 불일치
- Git HEAD 불일치 또는 tracked source 수정
- archive에서 `.source-commit` 누락
- root license 파일 누락; 단 E-03은 `NOASSERTION` 검토 기록 누락
- 파일 추가·삭제·내용 변경, symlink target 변경, tree manifest 자체 checksum 불일치

일반 저장소 정적 검사는 upstream이 아직 없는 외부망 단계도 지원하므로 `./scripts/verify-offline-repositories.sh`의 기본 동작은 없는 디렉터리를 `SKIP`한다. 내부망 준비 완료/인수 검사는 반드시 `--require-all`을 사용한다.

## 문서 출처 분리 규칙

외부 원문과 자체 작성물을 같은 파일로 합치지 않는다. 외부 원문은 repository ID와 상대 경로를 유지하고, 자체 작성 해설에는 그 ID·commit·경로를 인용한다. 원문을 수정해야 하면 원본, patch, 적용 후 결과를 별도 파일로 보존한다. 폐쇄망 운영의 정본은 자체 작성 repository의 검토된 harness이고, 외부 repository는 근거와 장애 대응 참고자료다.

폐쇄망 에이전트는 먼저 이 저장소의 `docs/`, `configs/`, `scripts/`, `manifests/`에서 운영 결정을 찾고, 근거·upstream 동작·patch 계보가 필요할 때만 해당 E-ID를 검색한다. upstream에서 발견한 명령은 바로 실행하지 않으며 현재 profile과 자체 runbook에 반영된 승인 명령인지 다시 확인한다.

## 남은 승인 gate

- repository 전체 자료에 적용되는 공식 별도 반입 양식과 검사 주체
- E-03 root license `NOASSERTION` 처리 방식
- archive 또는 Git bundle 중 허용 형식과 최대 매체 크기
- 외부 원문과 자체 작성 repository에 부여할 각각의 승인번호·보관 위치
- GitHub PR·Issue 토론을 오프라인 정적 문서로 제출할 형식과 checksum 기록 위치
