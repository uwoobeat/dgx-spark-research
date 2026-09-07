# Offline upstream reference area

이 디렉터리는 별도 승인된 외부 GitHub repository를 폐쇄망에서 읽기 전용으로 탐색하기 위한 **배치 규약**만 추적한다. 외부 원문 자체는 이 public repository의 일부가 아니며 `upstreams/` 전체가 `.gitignore` 대상이다.

## Layout

`manifests/external-repository-references.tsv`의 `item_id`가 stable directory ID다.

```text
third_party/upstreams/E-01/
third_party/upstreams/E-02/
third_party/upstreams/E-03/
third_party/upstreams/E-04/
third_party/upstreams/E-05/
third_party/upstreams/E-06/
third_party/upstreams/E-07/
```

E-05와 E-06은 같은 upstream URL의 서로 다른 commit이므로 합치지 않는다. 각 디렉터리의 `.source-*` 파일은 반입 provenance metadata이며 upstream 저작물로 표시하지 않는다. 정확한 파일 형식, 생성 gate와 license 예외는 `docs/12-external-repository-reference-submission.md`를 따른다.

## Offline gate and search

```bash
./scripts/verify-offline-repositories.sh --require-all
rg -n --hidden -g '!.git/**' '<exact-symbol-or-error>' third_party/upstreams/E-03
```

검증이 실패하면 해당 원문을 근거 또는 실행 입력으로 사용하지 않는다. 운영 결정은 먼저 이 repository의 `docs/`, `configs/`, `scripts/`, `manifests/`에서 찾고 upstream은 구현·provenance·장애 분석의 보조 자료로만 읽는다. upstream 파일을 이 위치에서 수정하지 않는다.
