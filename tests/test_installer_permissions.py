"""Installer parent-permission policy, exercised without network or root privileges."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INSTALL = ROOT / 'scripts' / 'install.sh'


class InstallerParentPermissions(unittest.TestCase):
    def check_parent(self, mode, uid, gid, allow, warning=False):
        with tempfile.TemporaryDirectory(prefix='drive-doctor-perms-') as tmp:
            work = pathlib.Path(tmp)
            parent = work / 'scripts'
            parent.mkdir()
            fakebin = work / 'bin'
            fakebin.mkdir()
            calls = work / 'wget-called'

            (fakebin / 'id').write_text(
                '#!/bin/sh\n'
                'if [ "$1" = "-u" ]; then echo 0; exit 0; fi\n'
                'exec /usr/bin/id "$@"\n'
            )
            (fakebin / 'stat').write_text(
                '#!/bin/sh\n'
                'if [ "$1" = "-c" ] && [ "$3" = "$MOCK_PARENT" ]; then\n'
                '  case "$2" in\n'
                '    %a) printf "%s\\n" "$MOCK_MODE" ;;\n'
                '    %u) printf "%s\\n" "$MOCK_UID" ;;\n'
                '    %g) printf "%s\\n" "$MOCK_GID" ;;\n'
                '    *) exit 98 ;;\n'
                '  esac\n'
                '  exit 0\n'
                'fi\n'
                'exec /usr/bin/stat "$@"\n'
            )
            (fakebin / 'wget').write_text(
                '#!/bin/sh\n'
                'echo yes > "$MOCK_DOWNLOAD_CALLED"\n'
                'exit 23\n'
            )
            for name in ('id', 'stat', 'wget'):
                (fakebin / name).chmod(0o755)
            env = dict(os.environ)
            env.update(
                PATH=str(fakebin) + os.pathsep + env.get('PATH', ''),
                MOCK_PARENT=str(parent),
                MOCK_MODE=str(mode),
                MOCK_UID=str(uid),
                MOCK_GID=str(gid),
                MOCK_DOWNLOAD_CALLED=str(calls),
            )
            p = subprocess.run(
                ['sh', str(INSTALL), str(parent / 'fresh-install')],
                env=env, text=True, capture_output=True, timeout=15,
            )
            self.assertEqual(calls.exists(), allow, f'{p.stdout}\n{p.stderr}')
            self.assertEqual(p.returncode, 23 if allow else 1, f'{p.stdout}\n{p.stderr}')
            self.assertEqual('root:root install parent is group-writable' in p.stderr, warning)
            self.assertFalse((parent / 'fresh-install').exists())
            self.assertEqual(list(parent.iterdir()), [], 'temporary staging should be cleaned up')

    def test_original_synology_root_root_775_allowed_with_warning(self):
        self.check_parent('775', '0', '0', allow=True, warning=True)

    def test_standard_755_allowed(self):
        self.check_parent('755', '0', '0', allow=True)

    def test_world_writable_root_root_777_rejected(self):
        self.check_parent('777', '0', '0', allow=False)

    def test_group_writable_nonroot_group_rejected(self):
        self.check_parent('775', '0', '100', allow=False)

    def test_group_writable_nonroot_owner_rejected(self):
        self.check_parent('775', '1000', '0', allow=False)

    def test_nonwritable_other_group_allowed(self):
        self.check_parent('755', '0', '100', allow=True)

    def test_sticky_world_writable_rejected(self):
        self.check_parent('1777', '0', '0', allow=False)


if __name__ == '__main__':
    unittest.main()
