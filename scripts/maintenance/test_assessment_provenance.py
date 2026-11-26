import hashlib
import pathlib
import tempfile
import unittest
import zipfile

from assessment_provenance import collect


class ProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mobi-provenance-contract-')
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.cache = self.root / 'cache'
        self.home = self.root / 'home'
        self.cache.mkdir()
        self.home.mkdir()
        self.roots = {'cache': str(self.cache), 'home': str(self.home)}

    def archive(self, entries):
        path = self.cache / 'a.jar'
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name, body in entries.items():
                archive.writestr(name, body)
        return {'cache': {'a.jar': {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                   'bytes': path.stat().st_size}}, 'home': {}}

    def test_named_claim_is_bound_to_actual_bytes_without_claiming_independent_attribution(self):
        fingerprints = self.archive({'META-INF/maven/example/api/pom.properties':
                                     'groupId=example\nartifactId=api\nversion=1.2.3\n'})
        report = collect(self.roots, fingerprints)
        row = report['archives'][0]
        self.assertEqual(row['metadata'][0]['component'], {'group': 'example', 'name': 'api', 'version': '1.2.3'})
        self.assertEqual(row['identity'], fingerprints['cache']['a.jar'])
        self.assertFalse(report['selected_classpath_proven'])
        self.assertFalse(report['adoption_authorized'])

    def test_missing_or_multiple_metadata_remains_unassigned_instead_of_guessing_from_filename(self):
        report = collect(self.roots, self.archive({'x.txt': 'not Maven metadata'}))
        self.assertIn('no_embedded_maven_identity', report['archives'][0]['gaps'])
        entries = {f'META-INF/maven/example/{name}/pom.properties':
                   f'groupId=example\nartifactId={name}\nversion=1.2.3\n' for name in ['one', 'two']}
        report = collect(self.roots, self.archive(entries))
        self.assertIn('multiple_embedded_owners', report['archives'][0]['gaps'])

    def test_oversized_metadata_is_not_decompressed_or_accepted(self):
        fingerprints = self.archive({'META-INF/maven/example/api/pom.properties': 'x' * 20_000})
        report = collect(self.roots, fingerprints)
        self.assertEqual(report['archives'][0]['metadata'], [])
        self.assertIn('embedded_metadata_size_or_encryption', report['archives'][0]['gaps'])

    def test_changed_fingerprint_and_escaped_archive_refuse(self):
        fingerprints = self.archive({})
        fingerprints['cache']['a.jar']['sha256'] = 'a' * 64
        with self.assertRaises(ValueError):
            collect(self.roots, fingerprints)
        outside = self.root / 'outside.jar'
        outside.write_bytes(b'outside')
        (self.cache / 'alias.jar').symlink_to(outside)
        with self.assertRaises(ValueError):
            collect(self.roots, {'cache': {'alias.jar': {'sha256': 'b' * 64, 'bytes': 7}}, 'home': {}})


if __name__ == '__main__':
    unittest.main()
