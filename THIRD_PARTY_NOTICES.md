# Third-party notices and repository license status

기준일: 2026-09-03

## Repository license status

이 저장소 자체의 배포 라이선스는 아직 결정되지 않았다. 루트 `LICENSE` 파일이 추가되기 전까지 이 저장소의 자체 작성물에 대해 사용·수정·재배포 권한이 부여된다고 해석해서는 안 된다. 아래 고지는 제3자 저작권과 라이선스 의무를 보존하기 위한 것이며 저장소 전체에 라이선스를 부여하지 않는다.

모델 snapshot/weight, OCI image, 외부 repository checkout 및 반입 payload는 이 public repository에 포함하지 않는다. 외부 repository의 고정 URL·commit과 반입 경계는 `manifests/external-repository-references.tsv` 및 `docs/12-external-repository-reference-submission.md`에서 별도로 관리한다.

## eugr/spark-vllm-docker-derived configuration

다음 로컬 설정은 아래의 고정된 upstream recipe를 바탕으로 폐쇄망 경로, immutable image digest 및 검증 gate를 추가해 수정한 파생 설정이다.

- 로컬 파일:
  - `configs/eugr-recipes/ds4f-base-offline.yaml`
  - `configs/profiles/ds4f-base-acceptance.sh`
  - `configs/profiles/ds4f-base-dspark.sh`
- Upstream repository: `https://github.com/eugr/spark-vllm-docker`
- Upstream commit: `e9cf3596c4d8ecd677056b1d14eb5dda16c1f86e`
- Upstream source: `recipes/deepseek-v4-flash-0731.yaml`
- Upstream copyright: Copyright (c) 2026 Eugene Rakhmatulin
- Upstream license: MIT License

MIT License

Copyright (c) 2026 Eugene Rakhmatulin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## tonyd2wild GLM reference boundary

GLM 실행 profile과 문서는 다음 고정 repository의 실행 보고, 명령 옵션 및 장애 분석을 참고했다.

- Repository: `https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark`
- Commit: `050081dc41ce6edd4d3f15fa19dc3410ba4210e3`
- Repository-level license status at review: `NOASSERTION` (root license not identified)

해당 repository의 checkout, Dockerfile, launcher, probe 및 patch 소스는 이 public repository에 vendor하지 않았다. `docker/sparse_attn_indexer_kpool_sm121.py`는 upstream 파일의 URL·크기·SHA-256과 파일 자체의 Apache-2.0 header만 manifest에 기록하며, 실제 파일은 별도 승인 경로의 외부 payload로 취급한다. 이 고지는 upstream repository 전체가 Apache-2.0이라고 주장하거나 재배포 권한을 부여하지 않는다.

## Other referenced projects

NVIDIA, vLLM, LiteLLM, Hugging Face model repositories와 그 밖의 커뮤니티 자료는 조사 근거 또는 외부 실행 자산으로만 참조한다. 각 항목의 license 표시는 해당 upstream의 권리를 대체하지 않는다. 실제 반입·배포 전에 고정 revision의 원문 license, notice 및 모델 사용 조건을 별도로 검토해야 한다.
