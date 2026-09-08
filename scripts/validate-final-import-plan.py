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
manual = set(refs("manual-oci-import.txt"))
retained = set(refs("quarantine-oci-successful.txt"))
required = set(refs("quarantine-oci-required.txt"))
require(len(manual) == 2 and len(retained) == 2 and not manual & retained
        and manual | retained == required, "OCI routes must partition four required images")
require(not refs("quarantine-oci-retry.txt"), "no third OCI retry round may be queued")
attempts = rows("quarantine-attempt-result.tsv")
require({r["artifact_ref"] for r in attempts if r["planned_route"] == "manual-oci-import"}
        == manual, "manual image plan differs from failed collection routing")
text = (ROOT / "docs/manual-import-source-links.txt").read_text()
require("https://github.com/" not in text, "repositories must not remain in manual list")
require(all(ref in text for ref in manual), "manual download list misses OCI refs")
for row in rows("separate-model-import.tsv"):
    require(row["source"] + "/tree/" + row["version"] in text, "manual list misses model pin")
print("final import plan verified: two portal rounds; manual models=3, OCI=2")
