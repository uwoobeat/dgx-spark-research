# DGX Spark 플랫폼 기준선

기준일: 2026-09-03 KST

## NVIDIA 공식 현재 구성

Founders Edition의 최신 공개 release note 기준값은 아래와 같다. 이는 구매 장비에 반드시 설치돼 있다는 보장이 아니라 비교 기준이다.

| 항목 | 공개 기준값 |
|---|---|
| DGX OS | 7.5.0 |
| GPU driver | 580.159.03 |
| CUDA Toolkit | 13.0.2 |
| kernel | 6.17 |
| UEFI | 1.110.13 |
| SoC firmware | 2.155.11 |
| CPU/architecture | 20-core ARM64 Grace |
| GPU/memory | GB10 Grace Blackwell, 128 GB unified memory |
| 관리망 | 10 GbE |
| cluster fabric | ConnectX-7, QSFP port당 최대 200 Gb/s Ethernet/RoCE |

NVIDIA 문서상 DGX OS, CUDA/cuDNN 개발 환경, Docker, NVIDIA Container Runtime/Toolkit와 GPU 연동이 기본 설치·구성된다. 따라서 정상 출고 장비에는 Docker나 driver를 별도 반입하지 않고 먼저 검증한다. 두 대의 버전 차이나 요구 이미지와의 호환 문제가 확인될 때만 recovery/local APT payload를 조건부 BOM으로 승격한다.

## 하드웨어·케이블 선행조건

각 장비에는 QSFP 포트 2개가 있으며 한 포트가 두 개의 Linux Ethernet/RoCE interface로 보인다. NVIDIA가 열거한 직접 연결 cable은 다음과 같다.

- Amphenol `NJAAKK-N911` / `NJAAKK0006`
- Luxshare `LMTQF022-SD-R`

승인 cable 한 개로 우선 두 대를 직접 연결한다. 일반 10 GbE 관리망과 TP traffic의 RoCE 주소를 분리한다. 예시 NIC 이름은 펌웨어/배선에 따라 달라질 수 있으므로 문서의 이름을 복사하지 말고 `ip -br link`와 `ibdev2netdev` 결과로 확정한다.

## 장비 도착 직후 수집

두 장비에서 각각 실행하고 결과를 서로 비교한다.

```bash
sudo ./scripts/collect-dgx-baseline.sh /var/tmp/dgx-baseline
```

최소 gate는 다음과 같다.

1. `uname -m`이 `aarch64`인가.
2. 두 장비의 DGX OS, driver, kernel, firmware가 동일한가.
3. `nvidia-smi`가 GB10과 정상 메모리를 표시하는가.
4. `docker info`와 NVIDIA runtime이 정상인가.
5. container에서 GPU가 보이는가. 이 검사는 이미 반입 승인된 vLLM image를 사용한다.
6. 양쪽 QSFP link가 `UP`, MTU와 RoCE interface 구성이 동일한가.
7. swap이 비활성화돼 있고 충분한 local disk가 있는가.

## 기본 탑재로 간주하지 않는 항목

다음은 DGX OS 기본 구성이라고 가정하지 않으며, 필요하면 container나 반입 payload에 포함한다.

- 모델별 vLLM/FlashInfer/B12X/GLM patch
- LiteLLM
- Hugging Face checkpoint와 remote-code 파일 전체
- 커뮤니티 launcher/patch source
- Python wheelhouse와 compiler toolchain
- Ray cluster helper(권고 mp 경로에는 불필요)
- 조직용 TLS certificate, firewall rule, service account와 API key

`curl`, `jq`, `sha256sum`, `split`, `systemd`, `iproute2`, `ping` 같은 일반 도구는 baseline에서 존재 여부를 확인한다. 빠졌을 때만 해당 DGX OS 버전에 맞춘 signed APT package와 전이 의존성을 반입한다.

baseline report의 `required-commands` 절은 command path와 `dpkg-query -S` package owner를 함께 남긴다. `MISSING`이 하나라도 있으면 [반입 BOM의 조건부 host 도구 표](04-import-bom.md)를 사용해 실제 장비와 같은 DGX OS repository에서 ARM64 `.deb` closure를 만든다. 일반 Ubuntu mirror의 임의 최신 package를 섞지 않는다.

## 업데이트 원칙

- 두 장비를 같은 image/driver/firmware 기준으로 맞춘다.
- 인터넷 연결을 전제로 하는 dashboard update나 `apt update`를 폐쇄망 절차에 넣지 않는다.
- 2026-04 이후 NVIDIA는 USB/local repository 기반 air-gapped deployment를 문서화했다. 필요 시 해당 장비 serial/지원 경로에 맞는 DGX Spark recovery image와 repository를 별도 승인한다.
- DGX Spark에는 일반 enterprise DGX OS ISO 대신 Spark 전용 recovery image를 사용한다.
- 정상 장비의 driver를 모델 image 때문에 임의 교체하지 않는다. host driver와 container CUDA 호환성 검증을 먼저 한다.
