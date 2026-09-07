# Security policy

## Supported state

이 저장소는 아직 공개 릴리스 전 조사·구축 단계다. 공개 후에는 `main`의 최신 승인 commit만 지원 대상으로 취급하며, DGX 실기 검증 전 항목은 문서에 표시된 acceptance gate를 통과하기 전까지 운영 보증으로 간주하지 않는다.

## Report a vulnerability privately

비밀정보 노출, 명령 주입, SSH 신뢰 경계 우회, checksum/digest 검증 우회 또는 모델·OCI 반입 경계 위반을 발견하면 공개 issue에 세부 내용을 게시하지 않는다. GitHub Security Advisory의 private reporting 기능이 활성화되어 있으면 이를 사용하고, 그렇지 않으면 저장소 소유 조직이 지정한 승인된 비공개 연락 채널로 보고한다.

보고서에는 재현 절차와 영향 범위를 포함하되 다음 값은 마스킹하거나 별도의 승인된 보안 채널로만 전달한다.

- 계정, 비밀번호, API key, token 및 개인키
- 실제 DGX IP, hostname, SSH username, host key와 내부망 구성
- `.env`, `state/` 진단 번들, 승인 문서 및 검역 포털 산출물 원본
- 모델 weight, OCI archive 및 별도 반입 payload

노출된 credential은 저장소 수정만으로 해결된 것으로 보지 않고 즉시 폐기·교체한다.

## Secret and publication boundary

- 실제 값은 Git에서 제외된 mode-`0600` 파일, SSH agent 또는 승인된 secret provider를 통해 주입한다.
- SSH는 고정된 `known_hosts`와 `StrictHostKeyChecking=yes`를 사용한다.
- 작업 디렉터리를 직접 ZIP/TAR로 배포하지 않는다. 공개·제출본은 검토된 Git 추적 파일에서 생성한다.
- 모델, OCI, 외부 repository checkout과 `third_party/upstreams/` payload는 이 repository에 commit하지 않는다.
- 공개 전 `scripts/validate-repository.sh`와 별도의 secret/internal-identifier scan을 실행하고 `git status --ignored`를 검토한다.

## Operational safety

`DGX_AGENT_MODE`는 외부망 조사와 내부망 SSH 작업의 실행 경계를 이룬다. `external` 또는 unset 상태에서는 SSH·설치·서비스 변경을 허용하지 않는다. `internal` 모드에서도 checksum, architecture, immutable image identity, SSH host key 및 명시적 `--apply` gate가 충족되지 않으면 변경 작업을 중지한다.
