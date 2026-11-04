import pathlib
import re
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENTRY = ROOT / 'syno_drive_doctor.sh'
SCRIPTS = sorted([ENTRY, *(ROOT / 'lib').glob('*.sh')])


def run(*args):
    return subprocess.run(['bash', str(ENTRY), *args], cwd=ROOT, text=True, capture_output=True, timeout=20)


class PublicSafetyTests(unittest.TestCase):
    def test_bash_syntax(self):
        for f in SCRIPTS:
            with self.subTest(f=f):
                p = subprocess.run(['bash', '-n', str(f)], capture_output=True, text=True)
                self.assertEqual(p.returncode, 0, p.stderr)
        p = subprocess.run(['sh', '-n', str(ROOT / 'scripts/install.sh')], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_help(self):
        p = run('--help')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('private', p.stdout.lower())

    def test_noninteractive_default_refused(self):
        p = run()
        self.assertEqual(p.returncode, 2)
        self.assertIn('No TTY', p.stderr)

    def test_dashboard_on_linux(self):
        p = run('health')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('Dashboard', p.stdout)

    def test_fault_inspection_is_readonly(self):
        p = run('stale-fault', 'inspect')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('pool-fault', p.stdout.lower())

    def test_no_private_backend(self):
        self.assertFalse((ROOT/'integrations/Synology_Stale_Pool_Fault/stale_pool_fault.py').exists())
        self.assertFalse((ROOT/'private').exists())

    def test_missing_private_backend_rejected(self):
        p = run('stale-fault', 'dry-run')
        self.assertNotEqual(p.returncode, 0)

    def test_unsupported_private_apply_cli(self):
        p = run('stale-fault', 'apply')
        self.assertEqual(p.returncode, 2)

    def test_noninteractive_upstream_execution_refused(self):
        p = run('hdd-db', 'run', '--restore')
        self.assertNotEqual(p.returncode, 0)

    def test_no_implicit_repairs(self):
        self.assertNotIn('btrfs check --repair', ENTRY.read_text())
        self.assertNotIn('git pull', ENTRY.read_text())

    def test_installer_dryrun(self):
        p = subprocess.run(['sh', str(ROOT/'scripts/install.sh'), '--dry-run'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('No files changed', p.stdout)
        self.assertIn('3f2b8d89', p.stdout)

    def test_no_private_or_captured_fixtures(self):
        for f in ROOT.rglob('*'):
            if not f.is_file():
                continue
            self.assertNotIn('v3-evidence', f.parts)
            self.assertFalse(f.name.endswith('.proposed.json'))
            self.assertNotIn('stale_pool_fault.py', str(f.relative_to(ROOT)))

    def test_submodule_metadata(self):
        text = (ROOT / '.gitmodules').read_text()
        self.assertIn('007revad/Synology_HDD_db.git', text)

if __name__ == '__main__':
    unittest.main()
