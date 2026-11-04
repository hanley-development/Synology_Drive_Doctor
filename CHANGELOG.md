# Changelog

## Unreleased (draft PR; not deployed)

- Read-only post-repair LED controller status snapshot (not proof of physical LED color).
- Correct `status_critical` log reads and selected-row previews to use the DSM `time` column instead of nonexistent `datetime`.
- Report configured versus present md members without classifying an intentionally vacant bay as a newly failed drive.
- Display SATA serials and any available enclosure mapping without trusting unavailable `synodisk` slot IDs.
- Show 2-second read-only Btrfs error-counter deltas alongside cumulative totals, without resetting counters.
- Add offline regression tests for the SQL query, RAID summary, LED snapshot and counter calculations.


## v0.3.0-rc1 (2026-11-03)

- New public distribution, with clean initial Git history and no machine-specific storage identifiers.
- Retained menu-driven diagnostic, RAID, SMART, alert and guarded maintenance tools.
- Moved any system-specific stale-pool-fault backend to a separately installed, checksum-verified private plugin.
- Kept 007revad HDD DB as a pinned Git submodule without modifying its code.
- Added a Git-free staged installer using `wget`/`curl`, and offline tests.
- Explicitly disabled unimplemented write tests and data scrubs.

Release candidate; DSM acceptance testing outstanding.
