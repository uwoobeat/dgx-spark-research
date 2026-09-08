# Python ARM64 반입

기준일: 2026-09-08, D-018. 사용자 결정으로 호스트 Python·pip와 기존 ARM64 반입물이 없다고 가정하고 선제 수집한다. 3.12는 사용자 필수 요구가 아니라 Ubuntu 24.04 및 기존 CPython 3.12 PyYAML wheel과 맞추기 위한 선택이다. 다른 minor 버전을 선택할 때는 wheel ABI와 하네스·설치 검증을 함께 변경한다. 시스템 Python을 임의 교체하지 않는다.

## 확정한 수집 범위

- Ubuntu Ports의 `noble`, `noble-updates`, `noble-security`, `main/universe`, architecture `arm64`.
- 최상위 `python3`, `python3.12`, `python3-pip`와 Depends/Pre-Depends 전이 의존성: **40개 `.deb`**. `arm64` 또는 `all`만 허용한다.
- CPython `3.12.3-1ubuntu0.16`, pip `24.0+dfsg-1ubuntu1.3`. 각 파일의 정확한 버전·원본 URL·크기·SHA-256·의존 관계는 [DEB manifest](../manifests/quarantine-python-debs.tsv)에 고정했다.
- `python3-setuptools`, `python3-wheel`, `python3-pkg-resources`, SSL·압축·SQLite·FFI 등 runtime 라이브러리도 포함한다. Recommends/Suggests는 제외한다. 현재 `pip --target` 설치에는 venv·compiler·Python headers가 필요하지 않다. 소스 빌드는 지원 범위가 아니다.
- 기존 [런처·패치·PyYAML 6건](../manifests/quarantine-raw-sources.tsv)과 합쳐 **코드·패키지 회차 RAW 46건**으로 제출한다. 레포지터리 8건 회차는 별도 유지하고 모든 Docker 이미지와 모델은 계속 수동 반입한다.

## 수집·검증 근거

외부망 Ubuntu 24.04 staging에서 다음 명령을 일반 사용자 권한으로 실행한다. 호스트에 설치하지 않으며 빈 dpkg status를 사용하는 격리 APT 상태로 수집하므로 staging PC의 기존 Python 설치 때문에 의존성을 생략하지 않는다. Ubuntu archive keyring으로 서명된 index를 검증하고 APT가 payload hash를 검증한다.

```bash
DGX_AGENT_MODE=external ./scripts/prepare-python-arm64.sh --collect
```

새로 생성한 `staging/python-arm64.*` 디렉터리에 signed InRelease·Packages index, URI 목록, `.deb`, `inventory.tsv`를 보존한다. 소스 저장소는 갱신되므로 재실행은 **새 후보 수집**이다. 기존 manifest를 자동 덮어쓰지 말고 버전·hash 차이를 검토한다. `inventory-python-debs.py`는 `.deb`를 실행하지 않고 architecture·size를 검사하고 SHA-256을 기록한다.

2026-09-08 포털 UI의 APT 대상은 Ubuntu 24.04 x86_64 두 종류만 제공했다. 따라서 포털 APT resolver를 사용하지 않고, 별도 수집으로 확정한 **40개 원본 `.deb` URL을 각각 RAW로 등록**한다. 포털 RAW 수집이 자동으로 의존성을 해결한다고 간주하지 않는다. UI 이름은 원래 Debian package name을 보존한다. 일괄 `NOASSERTION` 입력은 [패키지별 copyright 기반 요약](18-python-license-review.md)으로 정정했다. 이는 완전한 binary-wide SPDX 판정이나 법무 승인이 아니며, 추가 조건·파일 범위 검토와 조직 승인은 별도로 필요하다.

## 내부망 설치 gate

수집 대상은 Ubuntu 24.04 ARM64용 후보이며 **실제 DGX OS와의 설치 호환성 검증은 아직 남아 있다**. 전체 OS를 새로 구성하는 rootfs가 아니라 정상 DGX OS 위에 Python을 보완하는 payload다. APT/Debian이 기본 OS에 있다고 전제하는 Essential 도구까지 전부 새 OS로 구성한다는 의미가 아니다.

1. 양 노드 baseline에서 DGX OS/Ubuntu release·architecture·현재 패키지 버전을 확인한다. noble/arm64가 아니면 중단하고 해당 release로 재수집한다.
2. 승인 payload 40개의 SHA-256과 architecture를 manifest와 대조한다. repository metadata와 라이선스 검토 증빙도 반입한다.
3. 승인된 로컬 APT 저장소만 사용하여 `python3`, `python3.12`, `python3-pip` 설치를 **simulation**한다. 외부 sources를 사용하지 않으며 원격 apt update나 자동 보충 다운로드를 하지 않는다.
4. libc·OpenSSL·dpkg 등 기본 패키지의 변경/다운그레이드나 DGX vendor package 충돌이 있으면 중단한다. 모든 `.deb`를 `dpkg -i *.deb`로 일괄 설치하지 않는다. 수집된 버전을 반드시 덮어쓰는 것이 아니라 의존 조건을 충족하는 기존 패키지는 유지한다.
5. 검토·사람의 승인을 거쳐 필요한 패키지만 설치하고 `python3 -VV`, architecture/SOABI, `python3 -m pip --version`을 확인한 다음 기존 PyYAML local target 설치 절차를 수행한다.

근거: [Ubuntu Python 3.12 ARM64 배포 및 의존성](https://packages.ubuntu.com/noble-updates/python3.12), [NVIDIA Spark 소프트웨어 구성](https://docs.nvidia.com/dgx/dgx-spark-porting-guide/porting/software-requirements.html). 공식 지원 범위와 개별 장비 설치 여부는 구분한다.
