import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHA = 'a' * 40

class ReleaseWatch(unittest.TestCase):
    def check(self, *, existing=False, api_failure=False, prerelease=False, annotated=False):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for name, body in {
                'gh': '''#!/usr/bin/env python3
import os, sys
if sys.argv[-1] == 'repos/ggml-org/whisper.cpp/releases/latest':
    print(os.environ['RELEASE_JSON'])
else:
    if os.environ['FAIL_API'] == '1': sys.exit(1)
    print(os.environ['MARKERS'])
''',
                'git': '''#!/usr/bin/env python3
import os
print(os.environ['REFS'])
''',
            }.items():
                p = directory / name
                p.write_text(body)
                p.chmod(0o755)
            output = directory / 'output'
            refs = f'{SHA}\trefs/tags/v1.9.4'
            if annotated:
                refs = f'{"b" * 40}\trefs/tags/v1.9.4\n{SHA}\trefs/tags/v1.9.4^{{}}'
            env = dict(os.environ, PATH=f'{temp}:{os.environ["PATH"]}',
                       GH_REPO='test/repo', GITHUB_OUTPUT=str(output),
                       RELEASE_JSON=json.dumps(dict(id=123, tag_name='v1.9.4',
                                                    draft=False, prerelease=prerelease)),
                       FAIL_API=str(int(api_failure)), REFS=refs,
                       MARKERS=f'whisper-release-123-{SHA}' if existing else '')
            result = subprocess.run([str(ROOT / 'scripts/check-release.sh')],
                                    env=env, text=True, capture_output=True)
            return result.returncode, output.read_text() if output.exists() else ''

    def test_new_release_builds(self):
        code, output = self.check()
        self.assertEqual(code, 0)
        self.assertIn('changed=true', output)

    def test_success_marker_skips(self):
        code, output = self.check(existing=True)
        self.assertEqual(code, 0)
        self.assertIn('changed=false', output)

    def test_api_failure_does_not_trigger_build(self):
        code, output = self.check(api_failure=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(output, '')

    def test_prerelease_rejected(self):
        code, output = self.check(prerelease=True)
        self.assertNotEqual(code, 0)
        self.assertEqual(output, '')

    def test_annotated_tag_resolves_commit(self):
        code, output = self.check(annotated=True)
        self.assertEqual(code, 0)
        self.assertIn(f'revision={SHA}', output)

if __name__ == '__main__':
    unittest.main()
