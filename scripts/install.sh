#!/bin/sh
# Synology Drive Doctor v0.3.0-rc1: Git-free, staging-only installer.
# Does not execute Drive Doctor, Synology HDD DB or any repair action.
set -eu
umask 077
VERSION='v0.3.0-rc1'
DOCTOR_URL='https://codeload.github.com/hanley-development/Synology_Drive_Doctor/tar.gz/refs/heads/main'
UPSTREAM_SHA='3f2b8d89d17be94612fa35bc8aa1546d0ce7f9f1'
UPSTREAM_URL="https://codeload.github.com/007revad/Synology_HDD_db/tar.gz/$UPSTREAM_SHA"
DEST="${1:-/volume1/scripts/Synology_Drive_Doctor_$VERSION}"

usage() {
  cat <<'EOF'
Usage: sudo sh scripts/install.sh [absolute-empty-destination]
       sh scripts/install.sh --dry-run
       sh scripts/install.sh --help
Downloads a fresh, public Drive Doctor source archive and one pinned
upstream HDD DB source archive using wget/curl, into a NEW directory.
No replacement of old scripts, no execution of storage maintenance commands.
EOF
}
case "$DEST" in
  --help|-h) usage; exit 0 ;;
  --dry-run)
    printf 'Destination: %s\nSource: %s\nPinned upstream commit: %s\nNo files changed.\n' \
      '/volume1/scripts/Synology_Drive_Doctor_v0.3.0-rc1' "$DOCTOR_URL" "$UPSTREAM_SHA"
    exit 0 ;;
  /*) : ;;
  *) printf 'ERROR: destination must be an absolute path\n' >&2; exit 2 ;;
esac
case "$DEST/" in *'/../'*|*'/./'*|*'//'* ) printf 'ERROR: unsafe destination\n' >&2; exit 2 ;; esac
[ "$(id -u)" -eq 0 ] || { echo 'ERROR: run as root using sudo' >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo 'ERROR: tar required' >&2; exit 1; }
command -v mktemp >/dev/null 2>&1 || { echo 'ERROR: mktemp required' >&2; exit 1; }
if command -v wget >/dev/null 2>&1; then downloader=wget
elif command -v curl >/dev/null 2>&1; then downloader=curl
else echo 'ERROR: wget or curl required' >&2; exit 1; fi
[ ! -e "$DEST" ] && [ ! -L "$DEST" ] || { echo "ERROR: target already exists: $DEST" >&2; exit 1; }
PARENT=$(dirname "$DEST")
[ -d "$PARENT" ] && [ ! -L "$PARENT" ] || { echo 'ERROR: install parent must exist and not be a symlink' >&2; exit 1; }
# A group-writable root:root directory is supported on Synology (for example,
# /volume1/scripts mode 775). Do not allow arbitrary group write access:
# a member of that group could replace the entire installed folder later.
# Only group 0 (the root group) is treated as an administrative group here.
PARENT_MODE=$(stat -c %a "$PARENT") || exit 1
case "$PARENT_MODE" in
  ''|*[!0-7]*) echo 'ERROR: could not determine parent permissions' >&2; exit 1 ;;
esac
if [ $((0$PARENT_MODE & 0002)) -ne 0 ]; then
  echo 'ERROR: install parent is world-writable' >&2
  exit 1
fi
if [ $((0$PARENT_MODE & 0020)) -ne 0 ]; then
  PARENT_UID=$(stat -c %u "$PARENT") || exit 1
  PARENT_GID=$(stat -c %g "$PARENT") || exit 1
  if [ "$PARENT_UID" != 0 ] || [ "$PARENT_GID" != 0 ]; then
    echo 'ERROR: group-writable install parent must be owned by root:root (UID/GID 0)' >&2
    exit 1
  fi
  # Accepted root:root directory: no warning needed for a supported layout.
fi
TEMP=$(mktemp -d "$PARENT/.drive-doctor-install.XXXXXXXX") || exit 1
cleanup() { [ -n "${TEMP:-}" ] && [ -d "$TEMP" ] && rm -rf -- "$TEMP"; }
trap cleanup EXIT HUP INT TERM
fetch() {
  url=$1; output=$2
  if [ "$downloader" = wget ]; then wget -q -O "$output" "$url"
  else curl -fsSL --connect-timeout 15 --max-time 180 -o "$output" "$url"
  fi
}

printf 'Downloading reviewed public source...\n'
fetch "$DOCTOR_URL" "$TEMP/doctor.tar.gz"
printf 'Downloading pinned upstream HDD DB commit %s...\n' "$UPSTREAM_SHA"
fetch "$UPSTREAM_URL" "$TEMP/hdd.tar.gz"
# Validate basic archive structure before extraction. Never untar a user-provided path.
for archive in "$TEMP/doctor.tar.gz" "$TEMP/hdd.tar.gz"; do
  tar -tzf "$archive" > "$TEMP/list.txt" || { echo 'ERROR: invalid archive' >&2; exit 1; }
  if grep -E '^/|(^|/)\.\.(/|$)' "$TEMP/list.txt" >/dev/null; then
    echo 'ERROR: unsafe archive paths' >&2; exit 1
  fi
  tar -tvzf "$archive" > "$TEMP/details.txt" || exit 1
  if grep -E '^[lh]' "$TEMP/details.txt" >/dev/null; then
    echo 'ERROR: source archive contains links' >&2; exit 1
  fi
done
mkdir "$TEMP/stage"
tar -xzf "$TEMP/doctor.tar.gz" -C "$TEMP/stage" --strip-components=1
[ -f "$TEMP/stage/syno_drive_doctor.sh" ] && [ -f "$TEMP/stage/.gitmodules" ] || {
  echo 'ERROR: Drive Doctor archive missing expected files' >&2; exit 1;
}
# Reject repo symlinks, which are unnecessary for this tool and risky under sudo.
if [ -n "$(find "$TEMP/stage" -type l -print | head -1)" ]; then echo 'ERROR: release archive has symlinks' >&2; exit 1; fi
mkdir -p "$TEMP/stage/integrations/Synology_HDD_db"
tar -xzf "$TEMP/hdd.tar.gz" -C "$TEMP/stage/integrations/Synology_HDD_db" --strip-components=1
[ -f "$TEMP/stage/integrations/Synology_HDD_db/syno_hdd_db.sh" ] || {
  echo 'ERROR: HDD DB archive missing upstream script' >&2; exit 1;
}
if [ -n "$(find "$TEMP/stage" -type l -print | head -1)" ]; then echo 'ERROR: upstream archive has symlinks' >&2; exit 1; fi
# Public source must contain neither a private plugin nor NAS evidence.
[ ! -e "$TEMP/stage/private" ] && [ ! -e "$TEMP/stage/integrations/Synology_Stale_Pool_Fault/stale_pool_fault.py" ] || {
  echo 'ERROR: private code unexpectedly bundled' >&2; exit 1;
}
cat > "$TEMP/stage/PINNED_UPSTREAM.txt" <<EOF
Project: 007revad/Synology_HDD_db
Revision: $UPSTREAM_SHA
Archive: $UPSTREAM_URL
EOF
chown -R 0:0 "$TEMP/stage"
chmod -R go-w "$TEMP/stage"
# Public sources are readable by the operator; no private plugin is installed.
# Source archive extraction under umask 077 otherwise leaves the root unreadable.
find "$TEMP/stage" -type d -exec chmod 755 {} \;
[ ! -e "$DEST" ] && [ ! -L "$DEST" ] || { echo 'ERROR: target created concurrently; refusing' >&2; exit 1; }
mv "$TEMP/stage" "$DEST"
printf '\nInstalled to %s\n' "$DEST"
printf 'Next (read-only): cd %s && bash -n syno_drive_doctor.sh lib/*.sh && bash syno_drive_doctor.sh health\n' "$DEST"
printf 'INFO: No DSM maintenance or repair action was executed.\n'
