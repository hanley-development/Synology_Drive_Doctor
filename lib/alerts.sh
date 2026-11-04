#!/usr/bin/env bash
# Synology disk log database and retained storage pool fault records.
# status_critical is NOT the same as a persistent pool faulty_disks classification.
show_critical_summary() {
  if [[ ! -r "$DSM_DISK_DB" ]]; then info 'DSM critical alert DB not accessible'; return 0; fi
  if ! has sqlite3; then warn 'sqlite3 unavailable'; return 0; fi
  local count
  count=$(sqlite3 "$DSM_DISK_DB" "SELECT COUNT(*) FROM logs WHERE level='err' AND msg='status_critical';" 2>/dev/null) || { warn 'Cannot query critical alert DB'; return 0; }
  printf 'DSM status_critical entries: %s\n' "$count"
}
show_critical() {
  section 'DSM status_critical drive log entries'
  [[ -r "$DSM_DISK_DB" ]] || { warn 'DSM disk log database unavailable.'; return 0; }
  has sqlite3 || { warn 'sqlite3 unavailable'; return 0; }
  sqlite3 -header -column "$DSM_DISK_DB" \
    "SELECT rowid,datetime,level,msg,model,serial FROM logs WHERE level='err' AND msg='status_critical' ORDER BY rowid DESC LIMIT 100;" 2>&1 || warn 'Error reading DSM disk log database.'
}
pool_fault_summary() {
  if [[ -r /run/space/space_table ]] && has python3; then
    python3 - <<'PY'
import json
try:
    with open('/run/space/space_table') as f: pools=json.load(f)
    for pool in pools:
        if not isinstance(pool,dict): continue
        faults=pool.get('faulty_disks')
        if isinstance(faults,list) and faults:
            print('Retained pool-fault set:',pool.get('id','?'),', '.join(str(x) for x in faults))
except Exception as exc:
    print('Unable to inspect pool fault classifications:',exc)
PY
  else
    info 'Pool fault metadata inspection unavailable (requires Python 3 and DSM space table).'
  fi
}
show_pool_faults() {
  section 'Retained pool-fault classifications (read-only)'
  pool_fault_summary
  info 'A retained serial in faulty_disks is not automatically proof of an active hardware fault.'
  info 'Correcting these records requires the separately guarded Synology_Stale_Pool_Fault backend.'
}
clear_status_critical() {
  root_required || return 1
  interactive_required || return 1
  [[ -f "$DSM_DISK_DB" ]] || { warn 'DSM disk log database missing'; return 1; }
  has sqlite3 || { warn 'sqlite3 unavailable'; return 1; }
  local rows rowid selected confirm_line
  show_critical
  printf '\nEnter the numeric rowid of ONE record to clear (blank to cancel): '
  IFS= read -r rowid || return 1
  [[ "$rowid" =~ ^[1-9][0-9]{0,12}$ ]] || { info 'Cancelled or invalid rowid'; return 1; }
  selected=$(sqlite3 -separator ' | ' "$DSM_DISK_DB" "SELECT rowid,model,serial,datetime FROM logs WHERE rowid=$rowid AND level='err' AND msg='status_critical';") || return 1
  [[ -n "$selected" ]] || { warn 'Selected row no longer exists'; return 1; }
  printf 'Selected DSM log row: %s\n' "$selected"
  info 'This removes ONE stored log alert. It does not change pool metadata, SMART state or an active hardware fault.'
  confirm CLEAR "Delete exactly rowid $rowid from DSM status_critical history?" || return 1
  # Preserve the complete original SQLite database via its supported online backup API.
  local backup_dir='/var/lib/synology-drive-doctor/alert-backups' backup affected
  umask 077
  [[ ! -L "$backup_dir" ]] || { warn 'Backup directory is a symlink; refusing'; return 1; }
  mkdir -m 700 -p -- "$backup_dir" || return 1
  [[ -O "$backup_dir" ]] || { warn 'Backup directory ownership is not trusted'; return 1; }
  backup=$(mktemp "$backup_dir/synodiskdb-XXXXXXXX.sqlite") || return 1
  if ! sqlite3 "$DSM_DISK_DB" ".backup '$backup'"; then
    warn 'Online SQLite backup failed, no delete attempted.'
    return 1
  fi
  sha256sum "$backup" > "$backup.sha256" || return 1
  info "Saved full pre-clear DSM log DB backup: $backup"
  # Re-check predicates under an immediate SQLite transaction; single rowid, numeric only.
  affected=$(sqlite3 -cmd '.timeout 1000' "$DSM_DISK_DB" "BEGIN IMMEDIATE; DELETE FROM logs WHERE rowid=$rowid AND level='err' AND msg='status_critical'; SELECT changes(); COMMIT;") || return 1
  [[ "$affected" == 1 ]] || { warn 'Record changed or was already absent; no matching critical alert deleted.'; return 1; }
  info 'Exactly one historical alert row deleted. Verify current DSM hardware status separately.'
  show_critical
}
alerts_sata() { section 'SATA errors and timeouts (recent log)'; if [[ -r /var/log/messages ]]; then grep -iE 'ata[0-9]|sata|resetting link|timed out|timeout|ncq|speed downshift' /var/log/messages | tail -160 || :; else warn 'No storage log'; fi; }
alerts_raid() { section 'RAID and Btrfs events'; if [[ -r /var/log/messages ]]; then grep -iE 'md[0-9]|raid|btrfs|degrad|resync|recovery|scrub' /var/log/messages | tail -160 || :; else warn 'No storage log'; fi; }
alerts_cache() { section 'SSD cache events'; if [[ -r /var/log/messages ]]; then grep -iE 'flashcache|cachedev|nvme|ssd cache' /var/log/messages | tail -140 || :; else warn 'No storage log'; fi; }
