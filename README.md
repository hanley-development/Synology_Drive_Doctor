# Synology Drive Doctor

**v0.3.0-rc1 — public release candidate.** Menu-driven Bash toolkit for Synology NAS storage diagnostics and **guarded** maintenance. This release does not include a machine-specific repair backend or any private NAS captures.

## What it does

- System Health Dashboard, drive/SMART reports, RAID/storage topology, Btrfs and SSD-cache status, DSM storage event logs, diagnostic export.
- Read-only LED controller snapshots during post-repair verification, device-serial reporting without assumed bay numbers, configured RAID membership summaries, and short-interval Btrfs error-counter comparisons.
- Menu-based maintenance for SMART self-tests and bounded file reads; actions require a terminal and explicit confirmation.
- Option to clear **one selected DSM `status_critical` historical alert** after making an online SQLite backup. This only affects historical alert records, **not** active drive faults, pool metadata, disk health or LED control.
- Original upstream [007revad/Synology_HDD_db](https://github.com/007revad/Synology_HDD_db) remains its own Git submodule, pinned to an upstream commit. Executing its compatibility updater requires explicit opt-in.
- Optional support for a separately installed, root-owned and SHA256-pinned private repair engine. **The public distribution has no storage metadata repair code.**

## Install without Git (Synology NAS)

Read [INSTALL.md](INSTALL.md). The public `scripts/install.sh` can download both source archives with `wget` (or curl), install into a **new** versioned directory and leave existing scripts untouched.

```bash
wget -O drive-doctor-install.sh https://raw.githubusercontent.com/hanley-development/Synology_Drive_Doctor/main/scripts/install.sh
less drive-doctor-install.sh
sudo sh drive-doctor-install.sh
```

These commands become usable after this release is merged to `main`. `wget` only needs HTTPS support and the NAS must be able to reach GitHub/codeload.github.com. The installer refuses to overwrite an existing destination.

## Manual source clone (Git-equipped workstation)

```bash
git clone --recurse-submodules https://github.com/hanley-development/Synology_Drive_Doctor.git
```

## Run

```bash
cd /volume1/scripts/Synology_Drive_Doctor_v0.3.0-rc1
bash -n syno_drive_doctor.sh lib/*.sh
bash syno_drive_doctor.sh --help
bash syno_drive_doctor.sh health
sudo bash syno_drive_doctor.sh
```

The interactive menu requires a terminal. **Do not** run updates, SQLite clearing, self-tests or private repairs during first read-only deployment. The toolkit does not automatically modify DSM or schedule jobs.

## Safety and limitations

This release is a **release candidate**, not a verified production NAS deployment. Read [docs/SECURITY.md](docs/SECURITY.md) and [docs/PRIVATE_INTEGRATION.md](docs/PRIVATE_INTEGRATION.md). It has no generic repair engine, and any backend from a different NAS/DSM build must fail its own qualification checks. Real NAS diagnostics can contain serials, so treat report exports as private.

## Tests

```bash
bash -n syno_drive_doctor.sh lib/*.sh
python3 -m unittest discover -s tests -v
```

## Acknowledgments

The HDD compatibility script is an independent project by **007revad**, integrated as a Git submodule and attributed to its upstream author. The parent project is MIT-licensed; upstream licensing remains governed by the upstream project.
