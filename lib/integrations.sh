#!/usr/bin/env bash
# Public plugin interfaces. No machine-specific repair implementation is distributed.
hdd_version() {
  [[ -r "$HDD_SCRIPT" ]] || { warn "HDD DB submodule missing: $HDD_SCRIPT"; return 1; }
  section 'HDD DB integration'
  printf 'Upstream script available: %s\n' "$HDD_SCRIPT"
  info 'The upstream project is pinned by the Git submodule. No updater is run here.'
}
hdd_options() {
  [[ -r "$HDD_SCRIPT" ]] || { warn 'HDD DB submodule missing'; return 1; }
  info 'For supported arguments, consult the upstream README. This menu never executes the upstream script.'
  if [[ -r "$HDD_ROOT/README.md" ]]; then
    grep -nE -- '(^#{1,4}.*(Option|Usage|Parameter)| --[a-zA-Z]| -[a-zA-Z])' "$HDD_ROOT/README.md" | head -70 || :
  else
    info 'No upstream README found; consult the original repository.'
  fi
}
hdd_run() {
  root_required || return 1
  interactive_required || return 1
  [[ -r "$HDD_SCRIPT" && ! -L "$HDD_SCRIPT" ]] || { warn 'Upstream HDD script missing or linked'; return 1; }
  local dir_uid script_uid dir_perms script_perms
  dir_uid=$(stat -c '%u' "$HDD_ROOT") || return 1
  script_uid=$(stat -c '%u' "$HDD_SCRIPT") || return 1
  dir_perms=$(stat -c '%a' "$HDD_ROOT") || return 1
  script_perms=$(stat -c '%a' "$HDD_SCRIPT") || return 1
  [[ "$dir_uid" == 0 && "$script_uid" == 0 && $((8#$dir_perms & 0022)) -eq 0 && $((8#$script_perms & 0022)) -eq 0 ]] || {
    warn 'HDD DB code must be owned by root and not group/other writable.'; return 1;
  }
  printf '\nUpstream HDD DB arguments: '
  printf '%q ' "$@"
  printf '\n'
  warn 'The original upstream script may modify DSM compatibility settings.'
  confirm RUN_HDD_DB 'Run unmodified upstream HDD DB with the displayed arguments?' || return 1
  bash "$HDD_SCRIPT" "$@"
}
hdd_run_prompt() {
  local args=() line
  hdd_options || return 1
  printf '\nEnter upstream options separated by spaces (no shell quoting), or blank for defaults: '
  IFS= read -r line || return 1
  [[ -z "$line" ]] || read -r -a args <<< "$line"
  hdd_run "${args[@]}"
}
hdd_restore() { hdd_run --restore; }

fault_backend_check() {
  [[ -f "$FAULT_ENGINE" && -f "$FAULT_SHA_FILE" ]] || {
    warn 'Private fault-repair plugin not installed. No repair capability is available.'; return 1;
  }
  has python3 && has sha256sum && has stat || { warn 'Python 3, sha256sum and stat are required'; return 1; }
  local p owner mode wanted got
  for p in "$FAULT_ROOT" "$FAULT_ENGINE" "$FAULT_SHA_FILE"; do
    [[ ! -L "$p" ]] || { warn 'Private plugin cannot contain symlinks'; return 1; }
    owner=$(stat -c '%u' "$p") || return 1
    mode=$(stat -c '%a' "$p") || return 1
    [[ "$owner" == 0 && $((8#$mode & 0022)) -eq 0 ]] || { warn 'Private plugin files must be root-owned and non-writable by group/others.'; return 1; }
  done
  wanted=$(tr -d '[:space:]' < "$FAULT_SHA_FILE") || return 1
  [[ "$wanted" =~ ^[0-9a-f]{64}$ ]] || { warn 'Invalid private plugin hash file'; return 1; }
  got=$(sha256sum "$FAULT_ENGINE" | awk '{print $1}') || return 1
  [[ "$got" == "$wanted" ]] || { warn 'Private plugin checksum mismatch; refusing'; return 1; }
}
fault_inspect() { show_pool_faults; }
fault_health() { show_mdstat; show_degraded; smart_summary; show_flashcache; }
fault_dry_run() {
  root_required || return 1
  fault_backend_check || return 1
  warn 'A private plugin dry-run reads live DSM state. Confirm the NAS is stable before running.'
  interactive_required || return 1
  confirm LIVE_PREFLIGHT 'Run the privately installed read-only live preflight?' || return 1
  python3 "$FAULT_ENGINE" --live --dry-run
}
fault_offline_help() {
  section 'Optional private storage fault integration'
  info 'This public project does not ship a storage-metadata repair engine.'
  info 'A separately reviewed, build-specific private plugin can be installed by an administrator.'
  info 'Routine diagnostics and fault inspection never invoke that plugin.'
  info 'No generic metadata repair, stale-classification clearing or automatic rollback is offered.'
}
fault_history() { fault_offline_help; info 'Audit/history is managed by the separately installed private plugin.'; }
fault_metadata_diff() { fault_offline_help; info 'Use the private plugin preflight to review an exact proposed change.'; }
fault_apply() {
  root_required || return 1
  interactive_required || return 1
  fault_backend_check || return 1
  fault_offline_help
  warn 'STORAGE METADATA MODIFICATION. Only proceed after independent validation and authorization.'
  printf '\nPath to independently approved, root-owned 0600 authorization JSON (blank cancels): '
  local auth owner mode
  IFS= read -r auth || return 1
  [[ -n "$auth" && -f "$auth" && ! -L "$auth" ]] || { info 'Cancelled or authorization path invalid.'; return 1; }
  owner=$(stat -c '%u' -- "$auth") || return 1
  mode=$(stat -c '%a' -- "$auth") || return 1
  [[ "$owner" == 0 && "$mode" == 600 ]] || { warn 'Authorization must be root-owned with permissions 0600'; return 1; }
  confirm APPLY_PRIVATE_STORAGE_REPAIR 'Run separately authorized, build-specific private backend apply?' || return 1
  python3 "$FAULT_ENGINE" --live --apply --authorization-file "$auth"
}
fault_verify() { show_pool_faults; show_mdstat; fault_history; info 'Observations alone are not proof of successful repair.'; }
