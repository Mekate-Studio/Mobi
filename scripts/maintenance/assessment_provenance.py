#!/usr/bin/env python3
"""Bounded metadata inspection of owned downloaded bytes; never imports artifacts."""
import hashlib
import json
import pathlib
import re
import sys
import zipfile

MAX_ARCHIVES = 768
MAX_METADATA = 16_384
COORDINATE = re.compile(r"^[A-Za-z0-9_.+\-]+$")


def collect(roots, fingerprints):
    archives = []
    gaps = []
    count = 0
    uninspected = {}
    for scope, files in fingerprints.items():
        root = pathlib.Path(roots[scope]).resolve(strict=True)
        for name, identity in sorted(files.items()):
            if not name.endswith('.jar'):
                kind = pathlib.Path(name).suffix or 'no_extension'
                uninspected[kind] = uninspected.get(kind, 0) + 1
                continue
            count += 1
            if count > MAX_ARCHIVES:
                gaps.append('archive_count_limit')
                continue
            path = root / name
            if path.is_symlink() or not path.resolve(strict=True).is_relative_to(root):
                raise ValueError('archive escaped owned cache')
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
            actual = digest.hexdigest()
            if actual != identity['sha256'] or path.stat().st_size != identity['bytes']:
                raise ValueError('downloaded artifact changed before metadata inspection')
            row = {'scope': scope, 'path': name, 'identity': identity, 'metadata': [], 'gaps': []}
            try:
                with zipfile.ZipFile(path) as archive:
                    entries = [entry for entry in archive.infolist()
                               if entry.filename.startswith('META-INF/maven/')
                               and entry.filename.endswith('/pom.properties')]
                    if len(entries) > 16:
                        row['gaps'].append('embedded_metadata_count_limit')
                    else:
                        for entry in entries:
                            if entry.file_size > MAX_METADATA or entry.flag_bits & 1:
                                row['gaps'].append('embedded_metadata_size_or_encryption')
                                continue
                            raw = archive.read(entry)
                            props = {}
                            for line in raw.decode('utf-8', errors='strict').splitlines():
                                if '=' in line and not line.lstrip().startswith(('#', '!')):
                                    key, value = line.split('=', 1)
                                    props[key.strip()] = value.strip()
                            component = {key: props.get(prop, '') for key, prop in
                                         [('group', 'groupId'), ('name', 'artifactId'), ('version', 'version')]}
                            if not all(COORDINATE.fullmatch(value) for value in component.values()):
                                row['gaps'].append('unreadable_embedded_coordinate')
                                continue
                            row['metadata'].append({'member': entry.filename, 'component': component,
                                                    'body': raw.decode('utf-8'),
                                                    'sha256': hashlib.sha256(raw).hexdigest()})
            except (zipfile.BadZipFile, UnicodeError, RuntimeError, OSError):
                row['gaps'].append('archive_metadata_unreadable')
            if not row['metadata']:
                row['gaps'].append('no_embedded_maven_identity')
            if len(row['metadata']) > 1:
                row['gaps'].append('multiple_embedded_owners')
            archives.append(row)
    return {'schema': 1, 'scope': 'owned_downloaded_jar_bytes', 'archives': archives,
            'gaps': sorted(set(gaps)), 'identity_authority': 'embedded_claims_not_independent_byte_attribution',
            'uninspected_downloaded_artifact_kinds': uninspected,
            'selected_classpath_proven': False, 'adoption_authorized': False}


if __name__ == '__main__':
    cache, home, fingerprint_path = sys.argv[1:]
    with open(fingerprint_path, encoding='utf-8') as stream:
        fingerprints = json.load(stream)
    json.dump(collect({'cache': cache, 'home': home}, fingerprints), sys.stdout)
