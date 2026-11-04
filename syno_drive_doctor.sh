#!/usr/bin/env bash
# Synology Drive Doctor v0.3.0-rc1 — orchestrator. No automatic repairs/updates.
set -u
DRIVE_DOCTOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
for f in common diagnostics raid alerts integrations maintenance updates menus; do
  # shellcheck disable=SC1090
  source "${DRIVE_DOCTOR_ROOT}/lib/${f}.sh" || exit 1
done
usage() {
  cat <<'HELP'
Synology Drive Doctor v0.3.0-rc1
Usage: bash syno_drive_doctor.sh [command [subcommand]]
No arguments: interactive menu (requires terminal)
Read-only: health | report | disks | raid | alerts | logs | hdd-db version | updates check | stale-fault inspect
Interactive menus: diagnostics | storage | events | maintenance | hdd-db | stale-fault | updates | settings
Guarded: stale-fault dry-run (requires optional private plugin, root and TTY)
         hdd-db run [upstream supported options] (upstream may modify DSM)
Help: --help
Neither update nor fault repair is automatic. Private fault apply requires separate authorization; no repair engine ships publicly.
HELP
}
main() {
  case "${1:-menu}" in
    menu) [[ -t 0 ]] || { error 'No TTY: use a documented CLI command.'; return 2; }; main_menu ;;
    health) dashboard ;;
    report|diagnostics-report) full_report ;;
    disks) list_disks; smart_summary ;;
    raid) show_mdstat; show_md_detail ;;
    alerts) show_critical; show_pool_faults ;;
    logs) recent_storage_logs ;;
    diagnostics) diagnostics_menu ;;
    storage) storage_menu ;;
    events) events_menu ;;
    maintenance) maintenance_menu ;;
    hdd-db) shift; case "${1:-menu}" in
        menu) hdd_menu ;;
        version) hdd_version ;;
        run) shift; hdd_run "$@" ;;
        options) hdd_options ;;
        *) usage; return 2;; esac ;;
    stale-fault) shift; case "${1:-menu}" in
        menu) fault_menu ;;
        inspect) show_pool_faults ;;
        dry-run) fault_dry_run ;;
        *) usage; return 2;; esac ;;
    updates) shift; case "${1:-menu}" in
        menu) updates_menu ;;
        check) updates_check ;;
        *) usage; return 2;; esac ;;
    settings) settings_menu ;;
    -h|--help|help) usage ;;
    *) error "Unknown command: $1"; usage; return 2 ;;
  esac
}
main "$@"
