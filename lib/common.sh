#!/usr/bin/env bash
# Shared helpers; expected to be sourced by the main controller.
SCRIPT_VERSION='0.3.0-rc1'
: "${DRIVE_DOCTOR_ROOT:?Missing project root}"
CONFIG_DIR="${DRIVE_DOCTOR_ROOT}/config"
STATE_DIR="${DRIVE_DOCTOR_ROOT}/state"
HDD_ROOT="${DRIVE_DOCTOR_ROOT}/integrations/Synology_HDD_db"
HDD_SCRIPT="${HDD_ROOT}/syno_hdd_db.sh"
# Optional local-only engine. Not part of this public repository or upstream submodule.
FAULT_ROOT="${DRIVE_DOCTOR_ROOT}/private"
FAULT_ENGINE="${FAULT_ROOT}/stale_pool_fault.py"
FAULT_SHA_FILE="${FAULT_ROOT}/stale_pool_fault.sha256"
DSM_DISK_DB='/var/log/synolog/.SYNODISKDB'
UPSTREAM_URL='https://github.com/007revad/Synology_HDD_db'
REPORT_DIR='/tmp/synology-drive-doctor'
READ_LIMIT_MIB=64
UPDATE_CHECK='manual'
UPDATE_MODE='ask'
if [[ -r "${CONFIG_DIR}/defaults.conf" ]]; then
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" == \#* || -z "$key" ]] && continue
    case "$key" in
      REPORT_DIR) [[ "$value" == /tmp/* || "$value" == /volume[0-9]/* ]] && REPORT_DIR="$value" ;;
      READ_LIMIT_MIB) [[ "$value" =~ ^(1|4|16|32|64)$ ]] && READ_LIMIT_MIB="$value" ;;
      UPDATE_CHECK) [[ "$value" =~ ^(manual|daily|weekly)$ ]] && UPDATE_CHECK="$value" ;;
      UPDATE_MODE) [[ "$value" =~ ^(ask|manual)$ ]] && UPDATE_MODE="$value" ;;
    esac
  done < "${CONFIG_DIR}/defaults.conf"
fi

has() { command -v "$1" >/dev/null 2>&1; }
hr() { printf '\n%s\n' '------------------------------------------------------------'; }
section() { hr; printf '%s\n' "$*"; hr; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; return 1; }
info() { printf 'INFO: %s\n' "$*"; }
root_required() { [[ "$(id -u)" == 0 ]] || { error 'This operation requires root (sudo).'; return 1; }; }
interactive_required() { [[ -t 0 && -t 1 ]] || { error 'Interactive confirmation required; refusing noninteractive execution.'; return 1; }; }
confirm() { # exact phrase, no background/scheduled confirmation
  local phrase="$1" message="$2" answer
  interactive_required || return 1
  printf '\n%s\n' "$message"
  printf 'Type %s to proceed: ' "$phrase"
  IFS= read -r answer || return 1
  [[ "$answer" == "$phrase" ]] || { info 'Cancelled.'; return 1; }
}
back_pause() { if [[ -t 0 ]]; then printf '\nPress Enter to return...'; IFS= read -r _ || :; fi; }
show_or_unavailable() { local path="$1"; [[ -r "$path" ]] && cat -- "$path" || warn "Unavailable: $path"; }
command_read() { local exe="$1"; shift; if has "$exe"; then "$exe" "$@"; else warn "Missing required tool: $exe"; return 127; fi; }
menu_choice() { local answer; printf '\nChoose an option: ' >&2; IFS= read -r answer || return 1; printf '%s' "$answer"; }
run_menu() { # title; numbered labels joined by | ; callback name
  local title="$1" labels="$2" handler="$3" choice
  while :; do
    section "$title"
    local i=1 v
    IFS='|' read -r -a _menu_labels <<< "$labels"
    for v in "${_menu_labels[@]}"; do printf '%2d) %s\n' "$i" "$v"; ((i+=1)); done
    printf '\n 0) Back / Exit\n'
    choice=$(menu_choice) || return 0
    if [[ ! "$choice" =~ ^[0-9]{1,3}$ ]]; then
      warn "Invalid option: $choice"; continue
    fi
    choice=$((10#$choice))
    ((choice == 0)) && return 0
    if ((choice < 1 || choice >= i)); then
      warn "Invalid option: $choice"; continue
    fi
    "$handler" "$choice" || warn 'Operation did not complete successfully.'
    back_pause
  done
}
valid_sata_disk() { [[ "$1" =~ ^/dev/sata[0-9]+$ && -b "$1" ]]; }
choose_disk() {
  local candidates=() p i=1 selection
  for p in /dev/sata[0-9]*; do [[ -b "$p" ]] && [[ "$p" =~ ^/dev/sata[0-9]+$ ]] && candidates+=("$p"); done
  if ((${#candidates[@]} == 0)); then warn 'No SATA block devices found.'; return 1; fi
  printf '\n'; for p in "${candidates[@]}"; do printf '%2d) %s\n' "$i" "$p"; ((i+=1)); done
  printf 'Select disk: '; IFS= read -r selection || return 1
  [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#candidates[@]})) || { warn 'Invalid drive selection.'; return 1; }
  SELECTED_DISK="${candidates[selection-1]}"
}
