#!/usr/bin/env python3
"""Inventory APT-authenticated ARM64 payloads; never executes downloaded code."""
import csv
import hashlib
from pathlib import Path
import shlex
import subprocess
import sys

work = Path(sys.argv[1]).resolve()
review_path = Path(__file__).resolve().parents[1] / 'manifests/python-deb-license-review.tsv'
with review_path.open() as f:
    reviews = {(r['name'], r['version'], r['artifact_sha256']): r['license_summary']
               for r in csv.DictReader(f, delimiter='\t')}
uris = {}
for line in (work / "uris.txt").read_text().splitlines():
    if line.startswith("'https://"):
        url, filename, size, *_ = shlex.split(line)
        uris[filename] = (url, int(size))
fields = ["name", "version", "architecture", "url", "filename", "bytes", "sha256",
          "depends", "pre_depends", "license", "purpose_ko", "import_route"]
rows = []
for path in sorted((work / "archives").glob("*.deb")):
    metadata = subprocess.check_output([
        "dpkg-deb", "--show",
        "--showformat=${Package}\n${Version}\n${Architecture}\n${Depends}\n${Pre-Depends}\n", str(path),
    ], text=True).splitlines()
    name, version, arch, depends, pre_depends = metadata
    if arch not in ("arm64", "all"):
        raise SystemExit("Wrong architecture: " + str(path))
    url, size = uris[path.name]
    payload = path.read_bytes()
    if len(payload) != size:
        raise SystemExit("Size mismatch: " + str(path))
    digest = hashlib.sha256(payload).hexdigest()
    # Never inherit reviewed licensing across changed package content/version.
    license_summary = reviews.get((name, version, digest), "NOASSERTION")
    rows.append(dict(zip(fields, [name, version, arch, url, path.name, size,
        digest, depends, pre_depends,
        license_summary, "DGX Spark 호스트 Python 3.12·pip 설치 및 전이 의존성 (ARM64)",
        "quarantine-code-round"])))
if len(rows) != len(uris) or not {"python3", "python3.12", "python3-pip"} <= {r["name"] for r in rows}:
    raise SystemExit("Incomplete collection")
with (work / "inventory.tsv").open("w") as f:
    writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
print(f"Verified architecture/size and hashed {len(rows)} APT-collected packages: {work / 'inventory.tsv'}")
