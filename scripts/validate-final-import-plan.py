#!/usr/bin/env python3
"""Offline cross-check of the two portal rounds and manual-only payloads."""
import csv
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def rows(name):
    with (ROOT / "manifests" / name).open() as f:
        return list(csv.DictReader(f, delimiter="\t"))
def refs(name):
    return [line for line in (ROOT / "manifests" / name).read_text().splitlines()
            if line and not line.startswith("#")]
def require(condition, message):
    if not condition:
        raise SystemExit("ERROR: " + message)

source = rows("quarantine-repository-sources.tsv")
external = {r["item_id"]: r for r in rows("external-repository-references.tsv")}
require(len(source) == 8 and {r["item_id"] for r in source} ==
        set(external) | {"S-01"}, "source round must contain exactly E-01..E-07 and S-01")
for row in source:
    repo, pin = row["repository"], row["pin"]
    require(row["name"] == repo.removeprefix("https://github.com/").removesuffix(".git"),
            "repository display name must preserve upstream owner/repository")
    require(re.fullmatch(r"https://github\.com/[^/]+/[^/]+\.git", repo) is not None
            and re.fullmatch(r"[0-9a-f]{40}", pin) is not None, "invalid repository pin")
    require(row["download_url"] == repo[:-4] + "/archive/" + pin + ".zip",
            "archive URL must match repository and commit")
    require(row["artifact_type"] == "repository-source-zip"
            and row["import_route"] == "quarantine-repository-round", "invalid source route")
    require(row["archive_sha256"] == "PENDING_AFTER_PORTAL_COLLECTION"
            or re.fullmatch(r"[0-9a-f]{64}", row["archive_sha256"]) is not None,
            "invalid source archive digest")
    if row["item_id"] in external:
        upstream = external[row["item_id"]]
        require((repo, pin, row["license"]) ==
                (upstream["repository"], upstream["pin"], upstream["license"]),
                "source round differs from external reference")
    else:
        require(repo == "https://github.com/uwoobeat/dgx-spark-research.git",
                "S-01 must identify own repository")
for row in rows("quarantine-raw-sources.tsv"):
    require(row["name"] == row["url"].rsplit("/", 1)[-1],
            "RAW display name must preserve original filename")
manual = set(refs("manual-oci-import.txt"))
debs = rows("quarantine-python-debs.tsv")
reviews = rows("python-deb-license-review.tsv")
require(len(reviews) == 40 and len({r['name'] for r in reviews}) == 40,
        "Python license review must cover 40 packages")
review_by_name = {r['name']: r for r in reviews}
require(len(debs) == 40 and len({r["name"] for r in debs}) == 40,
        "Python ARM64 closure must contain 40 distinct packages")
require({"python3", "python3.12", "python3-pip"} <= {r["name"] for r in debs},
        "Python runtime/pip roots missing")
for row in debs:
    review = review_by_name.get(row['name'], {})
    require(review.get('version') == row['version'] and
            review.get('artifact_sha256') == row['sha256'] and
            review.get('license_summary') == row['license'] and
            row['license'] != 'NOASSERTION', 'DEB license review identity/summary mismatch')
    require(review.get('copyright_package') in review_by_name and
            review.get('copyright_path', '').startswith('/usr/share/doc/') and
            re.fullmatch(r'[0-9a-f]{64}', review.get('copyright_sha256', '')) is not None,
            'missing DEB copyright provenance')
    require(review.get('review_status') == 'copyright-reviewed-binary-scope-pending'
            and review.get('license_concluded') == 'NOASSERTION',
            'copyright summary must not imply final legal approval')
    require(row["architecture"] in ("arm64", "all") and
            row["url"].startswith("https://ports.ubuntu.com/ubuntu-ports/pool/") and
            row["url"].endswith("_" + row["architecture"] + ".deb"), "invalid DEB architecture/source")
    require(re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is not None
            and 0 < int(row["bytes"]) < 5000000000, "invalid DEB integrity metadata")
    require(row["import_route"] == "quarantine-code-round" and row["version"]
            and row["license"], "invalid DEB route/version/license")
require(len(manual) == 4, "manual OCI list must contain all four required images")
for name in ("quarantine-oci-required.txt", "quarantine-oci-successful.txt",
             "quarantine-oci-conditional.txt", "quarantine-oci-retry.txt"):
    require(not refs(name), "OCI input must not be queued for portal: " + name)
for name in ("quarantine-raw-sources.tsv", "quarantine-repository-sources.tsv"):
    for row in rows(name):
        url = row.get("url", row.get("download_url", ""))
        require("@sha256:" not in url and "/v2/" not in url,
                "OCI reference mixed into portal source input")
attempts = rows("quarantine-attempt-result.tsv")
require({r["artifact_ref"] for r in attempts if r["planned_route"] == "manual-oci-import"}
        == manual, "manual image plan differs from current collection routing")
text = (ROOT / "docs/manual-import-source-links.txt").read_text()
require("https://github.com/" not in text, "repositories must not remain in manual list")
manual_links = [line for line in text.splitlines() if line.startswith("https://")]
require(len(manual_links) == 7 and all(re.fullmatch(r"https?://\S+", line) for line in manual_links),
        "manual download document must contain exactly seven external URLs")
require(all(ref in text for ref in manual),
        "manual download document misses fixed OCI collection refs")
for row in rows("separate-model-import.tsv"):
    require(row["source"] + "/tree/" + row["version"] in text, "manual list misses model pin")
print("final import plan verified: two portal rounds; manual models=3, OCI=4")
