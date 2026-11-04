"""Regression coverage for read-only RC1 diagnostic fixes."""
import pathlib
import shlex
import shutil
import sqlite3
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"


def shell(command):
    setup = (
        f"DRIVE_DOCTOR_ROOT={shlex.quote(str(ROOT))}; "
        f"source {shlex.quote(str(LIB / 'common.sh'))}; "
        f"source {shlex.quote(str(LIB / 'diagnostics.sh'))}; "
        f"source {shlex.quote(str(LIB / 'raid.sh'))}; "
        f"source {shlex.quote(str(LIB / 'alerts.sh'))}; "
    )
    return subprocess.run(["bash", "-c", setup + command],
                          capture_output=True, text=True, timeout=20)


class ReadOnlyFixTests(unittest.TestCase):
    def test_md_membership_counts_do_not_confuse_empty_slot_with_disk_failure(self):
        with tempfile.TemporaryDirectory() as root:
            base = pathlib.Path(root)
            for name, expected, missing in [("md0", 5, 1), ("md2", 4, 0)]:
                d = base / name / "md"
                d.mkdir(parents=True)
                (d / "raid_disks").write_text(str(expected) + "\n")
                (d / "degraded").write_text(str(missing) + "\n")
                (d / "sync_action").write_text("idle\n")
            p = shell(f"show_md_health_summary {shlex.quote(root)}")
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("md0: 4/5 configured members present", p.stdout)
            self.assertIn("md2: 4/4 configured members present", p.stdout)
            self.assertIn("check whether a physical bay is intentionally empty", p.stdout)
            self.assertNotIn("md0: healthy", p.stdout.lower())

    def test_led_sysfs_snapshot_does_not_change_state(self):
        with tempfile.TemporaryDirectory() as root:
            base = pathlib.Path(root)
            for name, brightness in [("syno_led0", "1"), ("syno_led1", "0")]:
                d = base / name
                d.mkdir()
                (d / "brightness").write_text(brightness + "\n")
                (d / "max_brightness").write_text("1\n")
                (d / "trigger").write_text("[none] timer\n")
            p = shell(f"show_drive_led_status {shlex.quote(root)}")
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("syno_led0", p.stdout)
            self.assertIn("brightness=1/1", p.stdout)
            self.assertIn("syno_led1", p.stdout)
            self.assertIn("brightness=0/1", p.stdout)
            self.assertEqual((base / "syno_led0" / "brightness").read_text(), "1\n")

    def test_btrfs_short_interval_counter_delta(self):
        old = "[/dev/mock].read_io_errs 100\n[/dev/mock].write_io_errs 2"
        new = "[/dev/mock].read_io_errs 103\n[/dev/mock].write_io_errs 2"
        p = shell("btrfs_counter_diff " + shlex.quote(old) + " " + shlex.quote(new))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("[/dev/mock].read_io_errs: +3", p.stdout)
        self.assertNotIn("No increases observed", p.stdout)

    def test_btrfs_reset_is_not_reported_as_negative_delta(self):
        old = "[/dev/mock].read_io_errs 100"
        new = "[/dev/mock].read_io_errs 0"
        p = shell("btrfs_counter_diff " + shlex.quote(old) + " " + shlex.quote(new))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("comparison invalid", p.stdout)

    @unittest.skipUnless(shutil.which("sqlite3"), "sqlite3 command-line client unavailable")
    def test_dsm_alert_query_uses_time_column(self):
        with tempfile.TemporaryDirectory() as root:
            db = pathlib.Path(root) / "alerts.sqlite"
            with sqlite3.connect(db) as c:
                c.execute("CREATE TABLE logs (time INTEGER, level TEXT, msg TEXT, model TEXT, serial TEXT)")
                c.execute("INSERT INTO logs VALUES (123456, 'err', 'status_critical', 'Fixture', 'TESTSERIAL')")
            p = shell(f"DSM_DISK_DB={shlex.quote(str(db))}; show_critical")
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("TESTSERIAL", p.stdout)
            self.assertNotIn("no such column: datetime", p.stdout.lower())

    def test_alert_clear_selection_uses_actual_schema(self):
        alerts = (LIB / "alerts.sh").read_text()
        self.assertIn("SELECT rowid,model,serial,time FROM logs", alerts)
        self.assertNotIn("SELECT rowid,model,serial,datetime FROM logs", alerts)


if __name__ == "__main__":
    unittest.main()
