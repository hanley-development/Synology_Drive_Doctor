# Git-free staging installation

This release is meant for an **administrator-controlled, separate install directory**. It does not update existing scheduled jobs or old NAS scripts.

## One-step download of a reviewed installer

```sh
wget -O drive-doctor-install.sh https://raw.githubusercontent.com/hanley-development/Synology_Drive_Doctor/main/scripts/install.sh
less drive-doctor-install.sh
sudo sh drive-doctor-install.sh
```

The installer downloads **two** GitHub source archives: the public Drive Doctor code and the **exact pinned commit** of the unmodified upstream HDD DB, then stages them into a new directory. NAS does not need Git or Python for basic diagnostics. The installer requires `wget` or `curl`, `tar`, and working HTTPS certificates.

Default destination: `/volume1/scripts/Synology_Drive_Doctor_v0.3.0-rc1`. It refuses an existing destination or symlink, and does not overwrite existing installations. Stage first; run **read-only** checks before running the interactive menu.

Do **not** use an unauthenticated HTTP URL, disable TLS verification, or pipe an unread installer directly into a root shell. The source archives are retrieved over HTTPS; an independent archive signature/checksum is not provided in this candidate, so review before installing on a production NAS.

## Read-only checks

```sh
cd /volume1/scripts/Synology_Drive_Doctor_v0.3.0-rc1
bash -n syno_drive_doctor.sh lib/*.sh
bash syno_drive_doctor.sh --help
bash syno_drive_doctor.sh health
```

Only after checking permissions and source, start the menu with `sudo bash syno_drive_doctor.sh`. No repair operation is automatic.

## Restrictions

- The release contains no private repair backend and no captured storage metadata.
- There is no automatic Git-free updater yet; repeat the staging/install process for a separately named release.
- This is not a signed release bundle, and it has not been tested on a live DSM system.
