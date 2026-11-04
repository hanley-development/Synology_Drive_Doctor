# Optional private repair backend

The **public** Drive Doctor is general-purpose and does not include a storage-metadata repair engine.

To use a separately qualified, machine-specific backend, an administrator can install it under a trusted, root-owned `private/` directory beside `syno_drive_doctor.sh`. Keep that directory out of Git and out of public release archives.

Required locally created files:

- `private/stale_pool_fault.py`: private, independently reviewed backend.
- `private/stale_pool_fault.sha256`: exactly 64 lowercase hex characters, the independently verified SHA-256 of that backend, and a final newline.

Protect the directory and both files using root ownership and permissions that are not writable by groups or others. Drive Doctor checks both owner/mode and checksum before execution. Never copy this directory into a public repository or a downloadable package.

Only code explicitly reviewed for a particular NAS, firmware, metadata format and storage state should be installed. The public controller cannot establish that a custom backend is safe. Installation alone **does not** authorize applying changes. Authorization is separately checked by the backend and must be reviewed independently.

No private file or NAS-specific identifier is required for read-only dashboards and diagnostics. Maintenance functions that depend on a missing private backend refuse to run.
