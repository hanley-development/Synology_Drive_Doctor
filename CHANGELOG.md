# Changelog

## v0.3.0-rc1 (2026-11-03)

- New public distribution, with clean initial Git history and no machine-specific storage identifiers.
- Retained menu-driven diagnostic, RAID, SMART, alert and guarded maintenance tools.
- Moved any system-specific stale-pool-fault backend to a separately installed, checksum-verified private plugin.
- Kept 007revad HDD DB as a pinned Git submodule without modifying its code.
- Added a Git-free staged installer using `wget`/`curl`, and offline tests.
- Explicitly disabled unimplemented write tests and data scrubs.

Release candidate; DSM acceptance testing outstanding.
