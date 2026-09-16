"""Exercise command boundaries and refresh failure safety without a container engine."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Helpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.log = self.path / 'calls'
        mock = self.path / 'podman'
        mock.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALL_LOG'], 'a') as f:
    f.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + '\\n')
if sys.argv[1:3] == ['container', 'exists']:
    sys.exit(int(os.environ.get('EXISTS_STATUS', '1')))
if sys.argv[1:2] == ['pull']:
    sys.exit(int(os.environ.get('PULL_STATUS', '0')))
''')
        mock.chmod(0o755)
        for name in ('toolbox', 'distrobox'):
            (self.path / name).symlink_to(mock)
        self.env = dict(os.environ, PATH=f'{self.path}:{os.environ["PATH"]}',
                        CALL_LOG=str(self.log))

    def run_helper(self, script, *args, **env):
        return subprocess.run([str(ROOT / script), *args], env=self.env | env,
                              capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_refuses_implicit_replacement(self):
        result = self.run_helper('refresh-toolboxes.sh', 'rocm-fedora43', EXISTS_STATUS='0')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_pull_failure_never_removes_container(self):
        result = self.run_helper('refresh-toolboxes.sh', '--replace', 'rocm-fedora43',
                                 EXISTS_STATUS='0', PULL_STATUS='125')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any('rm' in c for c in self.calls()))

    def test_refresh_order(self):
        result = self.run_helper('refresh-toolboxes.sh', '--replace', 'vulkan-radv',
                                 EXISTS_STATUS='0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[1] for c in self.calls()], ['container', 'pull', 'rm', 'create'])

    def test_engine_error_is_not_absent_container(self):
        result = self.run_helper('refresh-toolboxes.sh', 'vulkan-radv', EXISTS_STATUS='125')
        self.assertEqual(result.returncode, 125)
        self.assertEqual(len(self.calls()), 1)

    def test_dry_run_has_no_side_effects(self):
        result = self.run_helper('refresh-toolboxes.sh', '--dry-run', '--replace', 'all')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())

    def test_gpu_selection_and_argument_boundaries(self):
        for backend in ('rocm-fedora43', 'vulkan-radv'):
            result = self.run_helper('scripts/run.sh', backend, 'whisper-cli', '-f',
                                     '/audio/a file.wav', MODELS_DIR='/tmp/model directory')
            self.assertEqual(result.returncode, 0, result.stderr)
            call = self.calls()[-1]
            self.assertIn('/tmp/model directory:/models:ro', call)
            self.assertEqual(call[-3:], ['whisper-cli', '-f', '/audio/a file.wav'])
            self.assertEqual('/dev/kfd' in call, backend == 'rocm-fedora43')

    def test_unknown_backend_runs_nothing(self):
        for script in ('scripts/build.sh', 'scripts/run.sh', 'refresh-toolboxes.sh'):
            self.assertEqual(self.run_helper(script, 'unknown').returncode, 2)
        self.assertFalse(self.log.exists())

if __name__ == '__main__':
    unittest.main()
