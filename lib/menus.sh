#!/usr/bin/env bash
# Three-level terminal navigation; dispatchers invoke the same CLI/read-only helpers.
main_menu() {
  run_menu 'Synology Drive Doctor v0.3.0-rc1' \
    'System Health Dashboard|Diagnostic Reports|RAID & Storage Pool Management|DSM Alerts & Event Logs|Maintenance & Repair Tools|Synology HDD Database Manager|Update Manager|Settings & Preferences|About / Help' main_select
}
main_select() {
  case "$1" in
    1) dashboard_menu;; 2) diagnostics_menu;; 3) storage_menu;; 4) events_menu;;
    5) maintenance_menu;; 6) hdd_menu;; 7) updates_menu;; 8) settings_menu;; 9) about_menu;;
  esac
}
dashboard_menu() {
  dashboard
  run_menu 'System Health Dashboard' \
    'Refresh dashboard|Overall storage and volumes|Physical disk status|RAID / pool health|SSD cache health|Active fault classifications|Recent storage activity' dashboard_select
}
dashboard_select() {
  case "$1" in
    1) dashboard;; 2) show_volume_info;; 3) list_disks; smart_summary;;
    4) show_mdstat; show_degraded;; 5) show_flashcache;;
    6) show_critical_summary; show_pool_faults;; 7) recent_storage_logs;;
  esac
}
diagnostics_menu() {
  run_menu 'Diagnostic Reports' \
    'Full Diagnostic Report|Drive Diagnostics & SMART|RAID & Storage Pool Diagnostics|SSD Cache Diagnostics|Storage Logs & Error Analysis|Export Diagnostic Reports' diagnostics_select
}
diagnostics_select() {
  case "$1" in
    1) full_report;; 2) drive_diagnostics_menu;; 3) raid_diagnostics_menu;;
    4) cache_diagnostics_menu;; 5) logs_diagnostics_menu;; 6) export_menu;;
  esac
}
drive_diagnostics_menu() {
  run_menu 'Drive Diagnostics & SMART' \
    'List physical drives|SMART summaries|Individual drive detail|SATA link state|SMART error history|NVMe health|Serial / physical bay mapping|Missing or unrecognized drives' drive_diagnostics_select
}
drive_diagnostics_select() {
  case "$1" in
    1) list_disks;; 2) smart_summary;; 3) smart_detail;; 4) smart_link_info;;
    5) smart_history;; 6) smart_nvme;; 7) serial_bay_mapping;; 8) list_disks; show_kernel_errors;;
  esac
}
raid_diagnostics_menu() {
  run_menu 'RAID & Storage Pool Diagnostics' \
    'Full RAID report|RAID member health|Storage pool / volume health|Degraded / missing member analysis|Btrfs error statistics|Rebuild history / progress|Storage topology report' raid_diagnostics_select
}
raid_diagnostics_select() {
  case "$1" in
    1) show_mdstat; show_md_detail;; 2) show_md_members;; 3) show_pool_detail; show_volume_info;;
    4) show_degraded;; 5) show_btrfs;; 6) show_resync; alerts_raid;; 7) show_topology;;
  esac
}
cache_diagnostics_menu() {
  run_menu 'SSD Cache Diagnostics' \
    'Cache overview|Cache mode / configuration|NVMe health|Cache counters|Cache read / write activity|Cache errors / warnings|Cache to volume mapping' cache_diagnostics_select
}
cache_diagnostics_select() {
  case "$1" in
    1|2|4|5|6) show_flashcache;; 3) smart_nvme;; 7) show_cache_topology;;
  esac
}
logs_diagnostics_menu() {
  run_menu 'Storage Logs & Error Analysis' \
    'Recent storage warnings|Search by serial / token|SATA transport errors|RAID / Btrfs events|SSD cache events|Current-boot kernel errors' logs_diagnostics_select
}
logs_diagnostics_select() {
  case "$1" in
    1) recent_storage_logs;; 2) ask_search_logs;; 3) alerts_sata;; 4) alerts_raid;;
    5) alerts_cache;; 6) show_kernel_errors;;
  esac
}
export_menu() {
  run_menu 'Export Diagnostic Reports' \
    'Full report|Physical disks and SMART|RAID and Btrfs|SSD cache|Storage log report' export_select
}
export_select() {
  case "$1" in
    1) export_report full;; 2) export_report disks;; 3) export_report raid;;
    4) export_report cache;; 5) export_report logs;;
  esac
}
storage_menu() {
  run_menu 'RAID & Storage Pool Management — observational tools' \
    'RAID array status|RAID member assignments|Pools / volumes|Missing or degraded members|Rebuild / resync progress|SSD cache configuration|Btrfs device statistics|Storage topology / dependencies|Configuration summary' storage_select
}
storage_select() {
  case "$1" in
    1) show_mdstat; show_md_detail;; 2) show_md_members;; 3) show_pool_detail; show_volume_info;;
    4) show_degraded;; 5) show_resync;; 6) show_cache_topology;; 7) show_btrfs;;
    8) show_topology;; 9) show_storage_configuration;;
  esac
}
events_menu() {
  run_menu 'DSM Alerts & Event Logs — read-only' \
    'DSM drive fault and alert checks|status_critical entries|Recent storage events|Search logs by serial|Search logs by bay / token|SATA timeouts / resets|RAID / pool events|SSD cache events|Export event log report' events_select
}
events_select() {
  case "$1" in
    1) show_critical_summary; show_pool_faults;; 2) show_critical;; 3) recent_storage_logs;;
    4|5) ask_search_logs;; 6) alerts_sata;; 7) alerts_raid;; 8) alerts_cache;;
    9) export_report logs;;
  esac
}
maintenance_menu() {
  run_menu 'Maintenance & Repair Tools — guarded actions' \
    'Drive health tests|RAID & storage verification|Storage read / I-O smoke tests|Clear a DSM critical alert|Stale pool-fault repair|Verify previous repair|Repair history & backups' maintenance_select
}
maintenance_select() {
  case "$1" in
    1) drive_tests_menu;; 2) verification_menu;; 3) smoke_menu;; 4) clear_status_critical;;
    5) fault_menu;; 6) fault_verify;; 7) fault_history;;
  esac
}
drive_tests_menu() {
  run_menu 'Drive Health Tests' \
    'Quick SMART health summary|Start SMART short self-test (guarded)|Start SMART extended self-test (guarded)|SMART test status / results|SMART error history' drive_tests_select
}
drive_tests_select() {
  case "$1" in
    1) smart_short_check;; 2) smart_selftest short;; 3) smart_selftest long;;
    4) smart_selftest_progress;; 5) smart_history;;
  esac
}
verification_menu() {
  run_menu 'RAID & Storage Verification' \
    'Verify current member status|Verify resync / degradation|Storage pool configuration|Btrfs error counters|Review scrub status|Start supported data scrub (not available)|Active verification task status' verification_select
}
verification_select() {
  case "$1" in
    1) show_md_members;; 2) show_resync; show_degraded;; 3) show_pool_detail;;
    4) show_btrfs;; 5|7) show_scrub_status;; 6) start_scrub;;
  esac
}
smoke_menu() {
  run_menu 'Storage Read / I-O Smoke Tests' \
    'Quick bounded file read (guarded)|Extended bounded read (guarded)|Controlled write/read test (not available)|Cache read activity counters|Review current error counters' smoke_select
}
smoke_select() {
  case "$1" in
    1|2) read_smoke;; 3) write_smoke;; 4) show_flashcache;; 5) show_current_error_counters;;
  esac
}
fault_menu() {
  run_menu 'Stale Pool-Fault — optional private plugin' \
    'Inspect stored pool-fault sets|Show affected drives and pools|Check live disk / RAID health|Run live preflight (dry-run)|Review proposed metadata change|View backup / repair history|Execute private backend repair (requires independent authorization)|Verify previous repair status' fault_select
}
fault_select() {
  case "$1" in
    1|2) fault_inspect;; 3) fault_health;; 4) fault_dry_run;; 5) fault_metadata_diff;;
    6) fault_history;; 7) fault_apply;; 8) fault_verify;;
  esac
}
hdd_menu() {
  run_menu 'Synology HDD DB — upstream by 007revad' \
    'Run compatibility database update (guarded)|Installed upstream version|View supported upstream flags|Configure options for a one-time run|Run with custom options (guarded)|Restore upstream database changes (guarded)|Check upstream GitHub updates|Install reviewed upstream update (guarded)|Read included upstream changelog' hdd_select
}
hdd_select() {
  case "$1" in
    1) hdd_run;; 2) hdd_version;; 3) hdd_options;; 4|5) hdd_run_prompt;;
    6) hdd_restore;; 7) updates_check;; 8) update_hdd_optional;;
    9) section 'Upstream changelog'; show_or_unavailable "$HDD_ROOT/CHANGES.txt";;
  esac
}
updates_menu() {
  run_menu 'Update Manager — updates are optional' \
    'Check upstream updates|Drive Doctor update information|Install reviewed 007revad HDD DB update|Stale Pool-Fault update policy|Installed component versions|Update history|Update preferences|Verify backend integrity' updates_select
}
updates_select() {
  case "$1" in
    1) updates_check;; 2) update_doctor_optional;; 3) update_hdd_optional;; 4) update_fault_optional;;
    5) show_versions;; 6) update_history;; 7) show_update_preferences;; 8) fault_backend_check;;
  esac
}
settings_menu() {
  run_menu 'Settings & Preferences' \
    'General defaults|Integration management|Update preferences|Log / report location|Diagnostic limits|Maintenance safety information|Scheduled tasks information|Current configuration|Reset defaults information' settings_select
}
settings_select() {
  case "$1" in
    1|8) section 'Configuration (data only)'; show_or_unavailable "$CONFIG_DIR/defaults.conf";;
    2) integrations_menu;; 3) show_update_preferences;;
    4) info "Report directory: $REPORT_DIR";;
    5) info "Bounded file read limit: $READ_LIMIT_MIB MiB";;
    6) fault_offline_help;;
    7) info 'No background/scheduled maintenance tasks are installed or created by v0.2.0.';;
    9) info 'Edit config/defaults.conf only after reviewing the supported keys. No automatic reset action.';;
  esac
}
integrations_menu() {
  run_menu 'Installed Integrations' \
    'HDD DB version|Stale Pool-Fault backend hash check|HDD DB upstream URL|Stale Pool-Fault safety scope' integrations_select
}
integrations_select() {
  case "$1" in
    1) hdd_version;; 2) fault_backend_check;; 3) info "$UPSTREAM_URL";; 4) fault_offline_help;;
  esac
}
about_menu() {
  run_menu 'About / Help' \
    'About Drive Doctor|CLI help|Credits and upstream repositories|Safety and authorization|Release notes|Licenses' about_select
}
about_select() {
  case "$1" in
    1) info "Synology Drive Doctor $SCRIPT_VERSION — storage diagnostics and an integration controller.";;
    2) usage;; 3) info "$UPSTREAM_URL"; info "$DOCTOR_REPO";;
    4) fault_offline_help;; 5) show_or_unavailable "$DRIVE_DOCTOR_ROOT/CHANGELOG.md";;
    6) show_or_unavailable "$DRIVE_DOCTOR_ROOT/LICENSE"; show_or_unavailable "$HDD_ROOT/LICENSE";;
  esac
}
