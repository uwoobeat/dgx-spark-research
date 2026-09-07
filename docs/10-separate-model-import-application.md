# 모델 별도 반입 신청

기준일: 2026-09-03 KST

수동 신청용 링크 정리: 2026-09-07. 아래 링크는 기존 고정 manifest를 바탕으로 정리했으며, 원격 배포 상태를 새로 확인한 날짜는 아니다.

## 정책과 범위

모델 snapshot은 크기와 무관하게 `quarantine.yethangul.kr`에 등록하지 않는다. 이 프로젝트에서는 두 target과 DFlash2 drafter를 별도 반입 문서에 **모델별 한 행**으로 추가한다. 개별 shard가 5 GB 미만인 DS4F와 전체 2.342 GB인 drafter에도 예외를 두지 않는다.

| 구분 | 모델 | revision | 정확한 크기 | 역할 |
|---|---|---|---:|---|
| M-01 | `deepseek-ai/DeepSeek-V4-Flash-0731` | `7872f01b1d1fe23eabc4c98b48bffcef5a386062` | 166,898,661,074 bytes | 필수 운영 baseline |
| M-02 | `RedHatAI/GLM-5.3-Flash-NVFP4` | `36c184c6cda000a481711306df5adde42f63321a` | 197,881,157,135 bytes | 필수 GLM target |
| M-03 | `incoai/GLM-5.3-Flash-DFlash2` | `bf582e4eacc1810f76656d1811693ff6c6737d2a` | 2,342,460,697 bytes | DFlash2 운영 경로의 필수 drafter; 비상업적 사용 확정 |

세 모델 합계는 367,122,278,906 bytes(367.122 GB, 341.909 GiB)다. 이는 한 번의 원본 payload 크기이며 파일시스템·manifest·매체 여유 공간은 별도다. 두 DGX에는 각각 동일한 세 revision을 배치한다.

## 반입 문서용 행

기계 판독 원본은 [separate-model-import.tsv](../manifests/separate-model-import.tsv)다. 아래 값은 포털 입력용이 아니다.

### 수동 신청용 원본 링크

신청서의 출처란에는 아래 원본 배포 URL을, 버전란에는 아래 신청 항목 표의 **40자리 revision 전체**를 복사한다. 고정 버전 파일 목록 URL은 해당 revision의 첨부 근거로 사용한다. 공식 신청 양식이 확보되기 전까지 아래 항목은 범용 작성 참고자료다.

| 항목 | 원본 배포 URL | 고정 버전 파일 목록 | 파일별 다운로드 URL·크기·upstream SHA 목록 |
|---|---|---|---|
| M-01 DS4F 기본 | [https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731) | [고정 revision 보기](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731/tree/7872f01b1d1fe23eabc4c98b48bffcef5a386062) | [ds4f-base.raw.tsv](../manifests/models/ds4f-base.raw.tsv) |
| M-02 GLM NVFP4 | [https://huggingface.co/RedHatAI/GLM-5.3-Flash-NVFP4](https://huggingface.co/RedHatAI/GLM-5.3-Flash-NVFP4) | [고정 revision 보기](https://huggingface.co/RedHatAI/GLM-5.3-Flash-NVFP4/tree/36c184c6cda000a481711306df5adde42f63321a) | [glm53-redhat-nvfp4.raw.tsv](../manifests/models/glm53-redhat-nvfp4.raw.tsv) |
| M-03 DFlash2 drafter | [https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2](https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2) | [고정 revision 보기](https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2/tree/bf582e4eacc1810f76656d1811693ff6c6737d2a) | [glm53-dflash2-draft.raw.tsv](../manifests/models/glm53-dflash2-draft.raw.tsv) |

파일별 TSV의 `resolve/<revision>/...` URL은 개별 파일의 원본 다운로드 주소다. 신청서는 모델별 한 행으로 작성하고 이 목록을 첨부한다. 실제 payload의 SHA-256은 수령 후 아래 절차로 확정하며, 아직 계산하지 않은 값은 미확정으로 기재한다.

### 신청 항목

| 문서 필드 | M-01 DS4F base | M-02 GLM NVFP4 | M-03 DFlash2 drafter |
|---|---|---|---|
| SW명 | DeepSeek-V4-Flash-0731 model snapshot | GLM-5.3-Flash-NVFP4 model snapshot | GLM-5.3-Flash-DFlash2 draft model snapshot |
| 버전 | revision `7872f01b1d1fe23eabc4c98b48bffcef5a386062` | revision `36c184c6cda000a481711306df5adde42f63321a` | revision `bf582e4eacc1810f76656d1811693ff6c6737d2a` |
| 출처 | `https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731` | `https://huggingface.co/RedHatAI/GLM-5.3-Flash-NVFP4` | `https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2` |
| 라이선스 정책 | upstream metadata MIT, LICENSE 첨부 | MIT(내부 결론, 2026-09-03); checkpoint 선언은 `NOASSERTION`, 원본 Z.AI MIT `LICENSE`·고지 첨부 | CC-BY-NC-ND-4.0; 출처·license 사본 보존, 비상업적 사용, 변경본 배포 금지 |
| 주요기능 | DS4F 0731 로컬 언어모델 추론 가중치·tokenizer·config | GLM 5.3 Flash compressed-tensors NVFP4 추론 가중치·tokenizer·config | GLM speculative decoding용 draft 가중치·config |
| 반입목적 | DGX Spark 2대 TP=2 DS4F 운영 baseline | DGX Spark 2대 TP=2 GLM 5.3 Flash 운영 검증 및 서빙 | DGX Spark 2대 TP=2 GLM DFlash2 speculative decoding |
| 배포범위 | 폐쇄망 DGX Spark 2대, 동일 revision 복제 | 폐쇄망 DGX Spark 2대, 동일 revision 복제 | 폐쇄망 DGX Spark 2대, 동일 revision 복제 |
| quarantine 등록 | 아니오 | 아니오 | 아니오 |
| 원본 해시값 | payload 수령 후 model tree manifest SHA-256 기재 | payload 수령 후 model tree manifest SHA-256 기재 | payload 수령 후 model tree manifest SHA-256 기재 |

`반입일자`, `반입 부서/요청부서`, `담당자`, `검증결과`, 실제 `배포일자`는 신청 조직과 승인 결과를 확인한 뒤 작성한다. 모델명만 쓰고 revision을 생략하지 않는다.

## 신청 전 첨부 증빙

각 모델 행에는 다음을 연결한다.

1. `artifacts.lock.yaml`의 repo, revision, size, file count, license metadata
2. `manifests/models/*.raw.tsv`의 파일별 path·bytes·upstream LFS SHA·고정 URL
3. source inventory TSV 자체의 SHA-256
4. 모델 카드와 LICENSE 사본; M-02는 checkpoint 자체의 `NOASSERTION`, 원본 Z.AI MIT `LICENSE`·copyright notice 및 2026-09-03 `license_concluded=MIT` 결정 기록, M-03은 2026-09-03 비상업적 사용 결정과 CC-BY-NC-ND-4.0 준수 기록
5. 대응 runtime image ID와 사용 profile

source inventory 자체의 현재 SHA-256은 다음과 같다.

| 모델 | source inventory | SHA-256 |
|---|---|---|
| M-01 | `models/ds4f-base.raw.tsv` | `5c0c2f638459c8cf6931cd6c6dc89801fefb83495f02dbc4e6f3cfc859182074` |
| M-02 | `models/glm53-redhat-nvfp4.raw.tsv` | `b568319e201357f3f64cdc1cdb4d093bf3f04ccfdf8793af5c8f765a43390cfd` |
| M-03 | `models/glm53-dflash2-draft.raw.tsv` | `43ae798ddecaddbb12f348ef2ab3a4267c82d6109be6b4f296dd54b8b09116ae` |

이 해시는 URL 목록의 정체성을 보장할 뿐 실제 다운로드된 모델 directory의 원본 해시를 대신하지 않는다.

## 승인 후 payload 해시 확정

승인된 staging host에서 snapshot 전체를 받은 뒤 모델마다 실행한다.

```bash
./scripts/make-model-tree-manifest.sh \
  /approved/models/<MODEL_DIRECTORY> \
  /approved/manifests/<MODEL_ID>.files.tsv

sha256sum /approved/manifests/<MODEL_ID>.files.tsv
./scripts/verify-model-tree.sh \
  /approved/models/<MODEL_DIRECTORY> \
  /approved/manifests/<MODEL_ID>.files.tsv
```

생성된 `<MODEL_ID>.files.tsv`는 모든 실제 파일의 상대 경로, bytes, SHA-256을 포함한다. 그 TSV 자체의 SHA-256을 신청서 `원본 해시값` 또는 별도 첨부란에 쓰고, TSV 원본도 함께 보존한다. Hub의 LFS SHA가 있는 파일은 두 값이 같은지 추가로 대조한다.

## 포장·매체 규칙

- snapshot의 상대 경로를 보존하며 config, tokenizer, processor, chat template, remote code, index, README/LICENSE를 weight와 함께 넣는다.
- 실제 binary 대신 Git LFS pointer가 들어 있으면 반입을 중지한다.
- quarantine 포털의 5 GB 제한 때문에 shard를 분할하지 않는다.
- 허용 매체/filesystem의 단일 파일 제한으로 분할이 요구될 때만 원본 SHA와 part SHA를 함께 기록하고 폐쇄망에서 검증 후 재조립한다.
- `MEDIA-SET.tsv`, 매체별 SHA manifest, read-back 결과, 승인 문서 번호를 같은 증빙 묶음에 둔다.
- 모델 payload와 포털 승인 OCI/최소 RAW payload는 신청 경로와 승인 증빙을 구분하되, 최종 매체 전체 manifest에서 함께 추적할 수 있다.

## 승인 gate

M-01과 M-02는 각 target 운영에 필수이고, M-03은 DFlash2 운영 경로에 필수다. M-03의 사용 범위는 2026-09-03 비상업적으로 확정됐다. 다음이 확정되기 전에는 다운로드·매체 기록을 완료 처리하지 않는다.

- 별도 신청서의 공식 양식과 승인번호
- 다운로드·악성코드/유해성 검사 책임 주체
- 허용 매체 종류, 용량, 단일 파일/파일시스템 제한
- M-02의 원본 MIT license·고지와 내부 license 결론 증빙, M-03의 출처 표시·license 사본 보존·비상업적 사용·변경본 배포 금지 준수 증빙

M-03의 별도 모델 반입 승인과 payload 검사는 위 사용 조건 결정과 별개의 반입 절차다. DFlash2 기술 검증이 실패하면 M-02와 `sm121-v8`을 사용하는 non-DFlash2 profile로 rollback하되, 이를 license 대체 경로로 표현하지 않는다.
- 세 payload의 최종 model tree manifest SHA-256
