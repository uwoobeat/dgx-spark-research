# Python ARM64 패키지 라이선스 검토

확인일: 2026-09-08. 대상은 [고정 DEB 40개](../manifests/quarantine-python-debs.tsv)이며 실제 수집 파일의 SHA-256을 먼저 대조했다. 패키지 내 `/usr/share/doc/<package>/copyright`를 읽고 다른 패키지를 가리키는 symlink도 해결했다.

## 표기 원칙

- 반입 목록의 `license`는 **copyright 기반 설명용 요약**이다. 완전한 SPDX expression이나 조직의 이용·배포 승인이 아니다. 실제 binary에 포함되는 파일 범위, source-only build/test/packaging 파일 및 번들 구성요소를 구분하는 최종 검토는 남아 있다.
- 모든 패키지에 동일한 `NOASSERTION`을 입력하던 임시 표기를 제거했다. 반면 [검토 근거 TSV](../manifests/python-deb-license-review.tsv)의 `license_concluded=NOASSERTION`은 binary 전체의 최종 판정이 아직 없음을 정직하게 기록한다. 라이선스가 없거나 사용 금지라는 뜻이 아니다.
- `OR` 선택과 `WITH` 예외를 보존한다. `Public-domain`, `BSD-variant`, `MIT/X11` 등은 원문 설명이며 임의의 SPDX ID로 바꾸지 않는다. source copyright에 나온 GPL을 library 전체의 단일 라이선스로 덮어쓰지 않는다.
- Debian copyright는 파일별 조건과 패키징 조건을 포함한다. 문자열을 전부 단순 AND로 연결하면 실제 binary의 조건을 잘못 표현할 수 있다. [Debian copyright 형식](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/)을 따른다.

## 패키지별 반입 표기

아래는 원문의 주요 조건을 요약한 것이며 전체 고지문을 대체하지 않는다. 추가 조건이 있는 항목은 원문을 함께 검토한다.

| 원본 패키지명 | 라이선스 요약 |
|---|---|
| ca-certificates | MPL-2.0; GPL-2.0-or-later |
| debconf | BSD-2-Clause |
| dpkg | GPL-2.0-or-later; public-domain-s-s-d |
| gcc-14-base | GPL-3.0-or-later; additional GCC notices |
| libacl1 | LGPL-2.1-or-later (library); GPL-2.0-or-later (other files) |
| libbz2-1.0 | bzip2 BSD-variant; GPL-2.0-only (packaging) |
| libc6 | LGPL-2.1-or-later (library); additional glibc notices |
| libcrypt1 | LGPL-2.1-or-later; BSD variants; public-domain notices |
| libdb5.3t64 | Sleepycat AND BSD-3-Clause; additional per-file notices |
| libexpat1 | MIT |
| libffi8 | MIT/Expat (library); additional per-file notices |
| libgcc-s1 | GPL-3.0-or-later WITH GCC-exception-3.1 |
| liblzma5 | Public-domain (liblzma source); additional binary notices |
| libmd0 | BSD variants; ISC; Beerware; public-domain notices |
| libncursesw6 | MIT/X11; BSD-3-Clause; X11 |
| libpcre2-8-0 | BSD-3-clause-Cambridge with binary exception; additional notices |
| libpython3-stdlib | PSF-2.0; historical Python and third-party notices |
| libpython3.12-minimal | PSF-2.0; historical Python and third-party notices |
| libpython3.12-stdlib | PSF-2.0; historical Python and third-party notices |
| libreadline8t64 | GPL-3.0-or-later; additional per-file/documentation notices |
| libselinux1 | Public-domain (library); GPL-2.0-only (other files) |
| libsqlite3-0 | Public-domain (SQLite); GPL-2.0-or-later (packaging) |
| libssl3t64 | Apache-2.0 (OpenSSL); additional per-file notices |
| libtinfo6 | MIT/X11; BSD-3-Clause; X11 |
| libzstd1 | BSD-3-Clause OR GPL-2.0-only; additional per-file notices |
| media-types | Public-domain information (ad-hoc notice) |
| netbase | GPL-2.0-only |
| openssl | Apache-2.0 (OpenSSL); additional per-file notices |
| python3 | PSF-2.0; historical Python and third-party notices |
| python3-minimal | PSF-2.0; historical Python and third-party notices |
| python3-pip | MIT (pip); Apache-2.0, BSD, ISC, MPL, LGPL, Python (bundled) |
| python3-pkg-resources | MIT; Apache-2.0; BSD-3-Clause (packaging) |
| python3-setuptools | MIT; Apache-2.0; BSD-3-Clause (packaging) |
| python3-wheel | MIT; (Apache-2.0 OR BSD-2-Clause); GPL-3.0-only (packaging) |
| python3.12 | PSF-2.0; historical Python and third-party notices |
| python3.12-minimal | PSF-2.0; historical Python and third-party notices |
| readline-common | GPL-3.0-or-later; additional per-file/documentation notices |
| tar | GPL-3.0-or-later; additional GPL/LGPL/Bison-exception notices |
| tzdata | Public-domain (database); ICU (additional files) |
| zlib1g | Zlib |

## 근거 재검증

[근거 TSV](../manifests/python-deb-license-review.tsv)는 각 DEB의 이름·버전·SHA-256, copyright를 제공하는 package, 해결된 경로·원문 SHA-256과 범위 주석을 기록한다. `libgcc-s1`→`gcc-14-base`, `libncursesw6`→`libtinfo6`, `libpython3.12-stdlib`→`libpython3.12-minimal`, `openssl`→`libssl3t64` 참조도 보존했다. 이 참조는 원문이 없는 것으로 잘못 판정하지 않기 위해 필요하다.

외부망 staging 또는 승인된 payload를 가진 로컬 환경에서 다음 읽기 전용 명령으로 근거를 재생성한다. 패키지를 설치하거나 원격 접근하지 않는다.

```bash
python3 scripts/extract-deb-copyright.py /srv/import/python-debs
```

패키지 payload에 copyright 원문이 들어 있으므로 반입 시 이를 제거하지 않는다. 참조하는 `/usr/share/common-licenses` 원문과 해당 라이선스의 고지·소스 제공 의무 충족 여부는 최종 승인 검토에서 확인한다. 이 문서는 법무 승인 증빙을 대신하지 않는다.
