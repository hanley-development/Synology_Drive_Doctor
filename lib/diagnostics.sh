#!/usr/bin/env bash
# Read-only reports and disk inspection.
model_name() {
  local path
  for path in /proc/sys/kernel/syno_hw_version /etc.defaults/synoinfo.conf; do
    [[ -r "$path" ]] || continue
    if [[ "$path" == *.conf ]]; then
      sed -n 's/^upnpmodelname="\?\([^" ]*\).*/\1/p' "$path" | head -1
    else cat "$path"; fi
    return
  done
  uname -n
}
dsm_version() {
  if [[ -r /etc.defaults/VERSION ]]; then
    grep -E '^(majorversion|minorversion|buildnumber|smallfixnumber)=' /etc.defaults/VERSION || :
  else warn 'DSM version file missing.'; fi
}
list_disks() {
  section 'Installed physical disks'
  if has synodisk; then synodisk --enum 2>&1 || warn 'synodisk enumeration failed'; else warn 'synodisk unavailable'; fi
  printf '\nKernel drive nodes:\n'
  ls -l /dev/sata[0-9]* /dev/nvme*n1 2>/dev/null || :
}
smart_one() {
  local disk="$1" output
  valid_sata_disk "$disk" || { warn "Unsupported drive path: $disk"; return 1; }
  if ! has smartctl; then warn 'smartctl not installed'; return 1; fi
  section "SMART: $disk (SAT passthrough)"
  # Explicit SAT passthrough is needed for Synology's /dev/sataN aliases.
  output=$(smartctl -d sat -a "$disk" 2>&1) || :
  if [[ -z "$output" ]]; then warn 'No SMART output'; return 1; fi
  printf '%s\n' "$output" | grep -E -i 'Device Model|Serial Number|User Capacity|Rotation Rate|SMART overall-health|SMART Health Status|SMART.*self-assessment|Power_On_Hours|Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|UDMA_CRC_Error_Count|No Errors Logged|ATA Error Count|Self-test|# [0-9]+ ' | head -75 || :
  printf 'Note: PASS does not exclude SATA/backplane timeouts; review kernel logs too.\n'
}
smart_summary() {
  section 'SATA SMART summary'
  local d found=0
  for d in /dev/sata[0-9]*; do
    [[ "$d" =~ ^/dev/sata[0-9]+$ && -b "$d" ]] || continue
    found=1; smart_one "$d" || :
  done
  ((found==1)) || warn 'No matching SATA block devices found.'
}
smart_nvme() {
  section 'NVMe SMART summaries'
  local d found=0
  for d in /dev/nvme*n1; do
    [[ -b "$d" ]] || continue
    found=1
    printf '\n%s\n' "$d"
    if has smartctl; then smartctl -a "$d" 2>&1 || :; elif has nvme; then nvme smart-log "$d" 2>&1 || :; else warn 'No NVMe health tool'; fi
  done
  ((found==1)) || warn 'No NVMe devices detected.'
}
smart_detail() { local SELECTED_DISK; choose_disk || return 1; smartctl -d sat -a "$SELECTED_DISK"; }
smart_tests_history() { local SELECTED_DISK; choose_disk || return 1; command_read smartctl -d sat -l selftest "$SELECTED_DISK"; }
smart_link_info() {
  section 'Physical SATA link information'
  if [[ -d /sys/class/ata_link ]]; then
    local p; for p in /sys/class/ata_link/*; do
      [[ -d "$p" ]] || continue
      printf '%s: ' "${p##*/}"; for v in sata_spd sata_spd_limit; do [[ -r "$p/$v" ]] && printf '%s=%s ' "$v" "$(cat "$p/$v")"; done; printf '\n'
    done
  else warn 'Kernel SATA link sysfs unavailable.'; fi
}
smart_history() {
  local SELECTED_DISK; choose_disk || return 1
  command_read smartctl -d sat -l error "$SELECTED_DISK"
}
serial_bay_mapping() {
  section 'SATA device identification (read-only)'
  local d serial found=0
  for d in /dev/sata[0-9]*; do
    [[ "$d" =~ ^/dev/sata[0-9]+$ && -b "$d" ]] || continue
    found=1
    serial='unavailable'
    if has smartctl; then
      serial=$(smartctl -d sat -i "$d" 2>/dev/null | awk -F: '/^[[:space:]]*Serial Number:/ {sub(/^[[:space:]]*/, "", $2); print $2; exit}')
      [[ -n "$serial" ]] || serial='unavailable'
    fi
    printf '%s  serial=%s\n' "$d" "$serial"
  done
  ((found)) || warn 'No SATA block devices available.'
  if has synodisk; then
    printf '\nDSM synodisk enumeration (slot IDs may be unknown/-1):\n'
    synodisk --enum 2>&1 || warn 'synodisk enumeration failed'
  fi
  local bay slot enclosure_found=0
  for bay in /sys/class/enclosure/*/*; do
    [[ -d "$bay" && -r "$bay/slot" ]] || continue
    enclosure_found=1
    IFS= read -r slot < "$bay/slot"
    printf 'Enclosure %s: slot=%s\n' "$bay" "$slot"
  done
  ((enclosure_found)) || info 'No readable sysfs enclosure slot mappings available.'
  info 'Do not infer physical bay from /dev/sataN numbering or synodisk Slot id -1; correlate drive serial with DSM Storage Manager.'
}
show_kernel_errors() {
  section 'Current-boot storage error lines (read-only)'
  if has dmesg; then
    dmesg 2>&1 | grep -iE 'ata[0-9]|sata|nvme|md[0-9]|btrfs|flashcache|i/o error|timeout|degraded|resetting link' | tail -100 || :
  else warn 'dmesg not available'; fi
}
recent_storage_logs() {
  section 'Recent storage events'
  local pattern='sata|ata[0-9]|md[0-9]|raid|degrad|fail|removed|critical|i/o error|timeout|reset|reconnect|deactiv|btrfs|flashcache|status_critical'
  if [[ -r /var/log/messages ]]; then
    grep -iE "$pattern" /var/log/messages | tail -150 || :
  else warn '/var/log/messages unavailable'; fi
}
search_storage_logs() {
  local value="$1" pattern
  [[ -n "$value" && ${#value} -le 80 && "$value" =~ ^[A-Za-z0-9_.:-]+$ ]] || { warn 'Invalid search token'; return 1; }
  if [[ -r /var/log/messages ]]; then grep -iF -- "$value" /var/log/messages | tail -200 || :; else warn 'No /var/log/messages'; fi
}
ask_search_logs() { local token; printf 'Enter disk serial, bay (e.g. ata2), or term: '; IFS= read -r token || return 1; search_storage_logs "$token"; }
show_flashcache() {
  section 'Flashcache statistics (read-only)'
  local p f found=0
  for p in /proc/flashcache/*; do
    [[ -d "$p" ]] || continue
    found=1; printf '\nCache: %s\n' "${p##*/}"
    for f in cache_info flashcache_stats flashcache_errors flashcache_progress; do
      [[ -r "$p/$f" ]] || continue
      printf '\n%s:\n' "$f"; head -70 "$p/$f"
    done
  done
  ((found==1)) || info 'No /proc/flashcache entries exposed by this DSM build.'
  info 'Cache counters can be boot-local and nonzero; this screen does not reset them.'
}
show_cache_topology() {
  section 'Device-mapper cache topology'
  if has dmsetup; then dmsetup ls --tree 2>&1 || :; dmsetup table 2>&1 || :; else warn 'dmsetup unavailable'; fi
  show_flashcache
}
show_volume_info() {
  section 'Mounted volumes and filesystem usage'
  if has df; then df -h 2>&1 || :; fi
  if has mount; then mount | grep -E '/volume[0-9]|cachedev' || :; fi
}
btrfs_counter_diff() {
  local before="$1" after="$2"
  awk '
  FNR==NR {
    if ($1 ~ /^\[[^]]+\]\.(read_io_errs|write_io_errs|flush_io_errs|corruption_errs|generation_errs)$/ && $2 ~ /^[0-9]+$/) old[$1]=$2
    next
  }
  ($1 in old) && $2 ~ /^[0-9]+$/ {
    seen++
    if ($2 < old[$1]) {
      printf "  %s: counter decreased/reset (comparison invalid)\n", $1
      invalid++
    } else if ($2 > old[$1]) {
      printf "  %s: +%.0f\n", $1, $2-old[$1]
      increased++
    }
  }
  END {
    if (!seen) print "  No comparable numeric counters (unavailable)."
    else if (!increased && !invalid) print "  No increases observed in this short sample."
  }
    ' <(printf '%s\\n' "$before") <(printf '%s\\n' "$after")
}

show_btrfs() {
  section 'Btrfs device error counters (NO -z/reset)'
  local v found=0 before after
  if ! has btrfs; then warn 'btrfs utility unavailable'; return 0; fi
  info 'These counters are cumulative, not proof of a currently failing disk.'
  for v in /volume[0-9]*; do
    [[ -d "$v" ]] || continue
    found=1
    printf '\n%s:\n' "$v"
    before=$(btrfs device stats "$v" 2>&1) || { printf '%s\n' "$before"; warn 'First Btrfs counter read failed'; continue; }
    printf '%s\n' "$before"
    sleep 2
    after=$(btrfs device stats "$v" 2>&1) || { warn 'Second Btrfs counter read failed; no delta available'; continue; }
    printf 'Counter changes during a 2-second read-only sample:\n'
    btrfs_counter_diff "$before" "$after"
  done
  ((found)) || warn 'No accessible /volumeN mounts.'
  info 'A short no-increase result does not exclude intermittent errors; compare longer-term observations if needed.'
}
show_drive_led_status() {
  section 'Drive LED controller (read-only sysfs snapshot)'
  local led brightness max_brightness trigger found=0 root="${1:-/sys/class/leds}"
  for led in "$root"/syno_led*; do
    [[ -d "$led" ]] || continue
    if [[ ! -r "$led/brightness" ]]; then
      warn "Unreadable LED state: ${led##*/}"
      continue
    fi
    IFS= read -r brightness < "$led/brightness" || { warn "Could not read ${led##*/}"; continue; }
    max_brightness='?'
    if [[ -r "$led/max_brightness" ]]; then
      IFS= read -r max_brightness < "$led/max_brightness" || max_brightness='?'
    fi
    trigger='unavailable'
    if [[ -r "$led/trigger" ]]; then
      IFS= read -r trigger < "$led/trigger" || trigger='unavailable'
    fi
    printf '%-12s brightness=%s/%s trigger=%s\n' "${led##*/}" "$brightness" "$max_brightness" "$trigger"
    found=1
  done
  ((found != 0)) || info 'No readable syno_led* controls exposed; LED state unavailable.'
  info 'Controller snapshot only: brightness/trigger may not match visible light; LED index, color and bay mapping are model-specific.'
}

show_quick_hints() {
  section 'Quick diagnosis hints'
  info 'RAID: compare [UUUU] member status with expected populated slots. An unpopulated bay is not necessarily a failed member.'
  info 'SMART: zeros for attributes 5/197/198 are encouraging; vendor PASS does not rule out transport resets.'
  info 'SATA: correlate ata timeout/reset/NCQ changes with serial and physical bay.'
  info 'DSM: status_critical entries and persistent pool faulty_disks records are different systems.'
  info 'Btrfs: nonzero historical I/O counters do not independently prove new bad sectors.'
  info 'SSD cache: cache-read tests do not necessarily exercise the origin HDDs.'
}
dashboard() {
  section 'System Health Dashboard — current observations'
  printf 'Hostname: %s\nNAS model: %s\n' "$(hostname)" "$(model_name)"
  dsm_version
  printf '\n'; show_mdstat; show_md_health_summary
  printf '\n'; if has df; then df -h | grep -E '^Filesystem|/volume[0-9]' || :; fi
  printf '\n'; show_critical_summary
  printf '\n'; pool_fault_summary
  printf '\n'; info 'This is a summary, not proof of full surface integrity.'
}
full_report() {
  section "Full Diagnostic Report — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Hostname: %s\nModel: %s\n' "$(hostname)" "$(model_name)"
  dsm_version
  list_disks; smart_summary; smart_nvme
  show_mdstat; show_md_health_summary; show_md_detail; show_volume_info; show_btrfs; show_flashcache
  show_critical; show_pool_faults; recent_storage_logs; show_quick_hints
}
export_report() {
  local kind="$1" tmp dir
  umask 077
  [[ ! -L "$REPORT_DIR" ]] || { warn 'Report directory is a symlink'; return 1; }
  if [[ ! -d "$REPORT_DIR" ]]; then mkdir -m 700 -p -- "$REPORT_DIR" || return 1; fi
  # Only use a report directory owned by the current user and non-world-writable.
  [[ -O "$REPORT_DIR" && -w "$REPORT_DIR" ]] || { warn 'Unsafe report directory ownership'; return 1; }
  dir=$(cd "$REPORT_DIR" && pwd -P) || return 1
  tmp=$(mktemp "$dir/doctor-${kind}-XXXXXXXX.txt") || return 1
  case "$kind" in
    full) full_report >"$tmp" 2>&1 ;;
    disks) { list_disks; smart_summary; smart_nvme; } >"$tmp" 2>&1 ;;
    raid) { show_mdstat; show_md_detail; show_volume_info; show_btrfs; } >"$tmp" 2>&1 ;;
    cache) show_flashcache >"$tmp" 2>&1 ;;
    logs) recent_storage_logs >"$tmp" 2>&1 ;;
    *) rm -f -- "$tmp"; warn 'Unknown report type'; return 1 ;;
  esac
  printf 'Report saved: %s\n' "$tmp"
}
