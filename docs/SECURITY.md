# Security model and supported operations

- **Read-only:** Dashboards, SMART reports, kernel/mdstat inspection, log filtering and diagnostics.
- **Active tests:** SMART self-tests and bounded file-read tests require TTY and typed confirmation.
- **Modifying operations:** Running upstream HDD compatibility updates, clearing selected DSM SQLite alert rows, and private plugin repair require root, an interactive terminal and explicit confirmation. Do not use those features on critical arrays without backups and a maintenance window.
- **Not implemented:** Direct write/read smoke test, starting a data scrub, automatic Drive Doctor upgrades, universal stale-pool-fault repair.
- **Private plugins:** Never bundled; only locally installed, root-owned and SHA256-verified plugins may be invoked. Code must be independently qualified for the target system.
- **Install:** Download source from GitHub, stage in a trusted location, reject symlinks, and verify ownership/permissions. Do not overwrite existing scripts or scheduled tasks. HTTPS transport protects downloads in transit but the installer is not a signed artifact.
- **Support logs:** Drive health output, diagnostic reports and exports contain device serial numbers. Do not upload those reports publicly without review.
- **Status:** Linux unit tests and shell syntax verification are not a substitute for Synology DSM acceptance testing. Use read-only features first.
