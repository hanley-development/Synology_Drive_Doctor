#!/usr/bin/env bash
# Maintenance uses explicit confirmation for any active test or mutation.
smart_selftest() {
  local SELECTED_DISK kind="$1"
  root_required || return 1
  interactive_required || return 1
  choose_disk || return 1
  has smartctl || { warn 'smartctl unavailable'; return 1; }
  info "SMART $kind test on $SELECTED_DISK can add significant disk I/O; do not overlap degraded/rebuilding arrays."
  confirm "START_${kind^^}_SMART" "Start a $kind SMART self-test?" || return 1
  smartctl -d sat -t "$kind" "$SELECTED_DISK"
}
smart_selftest_progress() { smart_tests_history; }
smart_short_check() { smart_summary; }
read_smoke() {
  local path resolved limit answer
  interactive_required || return 1
  section 'Bounded read smoke test'
  info 'Reads a chosen EXISTING regular file; no raw block devices, no filesystem writes.'
  info 'Reads may be served entirely from RAM or SSD cache. Not a surface scan.'
  printf 'Existing regular file path (blank cancels): '
  IFS= read -r path || return 1
  [[ -n "$path" && -f "$path" && ! -L "$path" ]] || { info 'Cancelled or invalid regular file.'; return 1; }
  # Do not accept proc, sys, device, or root-filesystem paths.
  resolved=$(readlink -f -- "$path") || { warn 'Could not resolve path'; return 1; }
  [[ "$resolved" =~ ^/volume[0-9]+/ && -f "$resolved" ]] || { warn 'File must resolve to a regular file under /volumeN/'; return 1; }
  path="$resolved"
  limit="$READ_LIMIT_MIB"
  info "Read limit: $limit MiB from $path"
  confirm READ_SMOKE "Initiate a bounded I/O read test on this file?" || return 1
  dd if="$path" of=/dev/null bs=1048576 count="$limit" 2>&1
}
write_smoke() {
  warn 'Controlled write/read smoke test is NOT IMPLEMENTED in v0.2.0.'
  info 'No test file was created. A safe temporary-file lifecycle and platform integration still need validation.'
  return 1
}
start_scrub() {
  warn 'Starting a data scrub is NOT IMPLEMENTED in v0.2.0.'
  info 'Use DSM Storage Manager for supported scrubbing after verifying maintenance compatibility and backups.'
  return 1
}
show_scrub_status() {
  section 'Last recorded scrub / current state'
  if has btrfs; then
    local v
    for v in /volume[0-9]*; do [[ -d "$v" ]] && btrfs scrub status "$v" 2>&1 || :; done
  else warn 'btrfs unavailable'; fi
  show_resync
}
show_current_error_counters() { show_btrfs; show_flashcache; }
