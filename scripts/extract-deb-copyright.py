#!/usr/bin/env python3
"""Read verified DEBs and resolve copyright links without executing/extracting code."""
import csv
import hashlib
import io
from pathlib import Path
import posixpath
import subprocess
import sys
import tarfile

root = Path(__file__).resolve().parents[1]
archives = Path(sys.argv[1]).resolve()
rows = list(csv.DictReader((root / 'manifests/quarantine-python-debs.tsv').open(), delimiter='\t'))
files, links, owners = {}, {}, {}
for row in rows:
    path = archives / row['filename']
    if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
        raise SystemExit('payload mismatch: ' + row['name'])
    with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb', '--fsys-tarfile', str(path)]))) as archive:
        for member in archive:
            name = posixpath.normpath('/' + member.name)
            if member.issym():
                links[name] = posixpath.normpath(posixpath.join(posixpath.dirname(name), member.linkname))
            elif member.isfile() and name.endswith('/copyright'):
                files[name] = archive.extractfile(member).read()
                owners[name] = row['name']

def resolve(name):
    for _ in range(20):
        if name in files:
            return name
        for prefix in sorted(links, key=len, reverse=True):
            if name == prefix or name.startswith(prefix + '/'):
                name = links[prefix] + name[len(prefix):]
                break
        else:
            break
    raise SystemExit('unresolved copyright: ' + name)

writer = csv.writer(sys.stdout, delimiter='\t', lineterminator='\n')
writer.writerow(['name', 'version', 'artifact_sha256', 'copyright_package', 'copyright_path', 'copyright_sha256'])
for row in rows:
    name = resolve('/usr/share/doc/' + row['name'] + '/copyright')
    writer.writerow([row['name'], row['version'], row['sha256'], owners[name], name,
                     hashlib.sha256(files[name]).hexdigest()])
