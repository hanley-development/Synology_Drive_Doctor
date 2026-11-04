#!/usr/bin/env bash
# RAID, storage and md metadata readbacks. No mdadm mutations.
show_mdstat() { section 'Linux md RAID: /proc/mdstat'; show_or_unavailable /proc/mdstat; }
show_md_health_summary() {
  section 'RAID membership summary (read-only)'
  local md expected degraded active action found=0 root="${1:-/sys/block}"
  for md in "$root"/md[0-9]*; do
    [[ -d "$md/md" && -r "$md/md/raid_disks" && -r "$md/md/degraded" ]] || continue
    found=1
    IFS= read -r expected < "$md/md/raid_disks"
    IFS= read -r degraded < "$md/md/degraded"
    if [[ "$expected" =~ ^[0-9]+$ && "$degraded" =~ ^[0-9]+$ ]] && (( degraded <= expected )); then
      active=$((expected - degraded))
      if ((degraded == 0)); then
        printf '%s: %s/%s configured members present; md reports no missing members\n' "${md##*/}" "$active" "$expected"
      else
        printf '%s: %s/%s configured members present; md reports %s missing member(s)\n' "${md##*/}" "$active" "$expected" "$degraded"
      fi
    else
      printf '%s: unreadable or unexpected membership counters (configured=%s missing=%s)\n' "${md##*/}" "$expected" "$degraded"
    fi
    if [[ -r "$md/md/sync_action" ]]; then
      IFS= read -r action < "$md/md/sync_action"
      printf '  sync_action=%s\n' "$action"
    fi
  done
  ((found)) || info 'No md RAID membership counters are available.'
  info 'An array missing configured members is not necessarily losing data: check whether a physical bay is intentionally empty.'
  info 'This summary does not establish DSM storage-pool health or drive LED state.'
}

show_md_detail() {
  section 'mdadm detail (read-only)'
  if ! has mdadm; then warn 'mdadm unavailable'; return 0; fi
  local md found=0
  for md in /dev/md[0-9]*; do
    [[ "$md" =~ ^/dev/md[0-9]+$ && -b "$md" ]] || continue
    found=1; printf '\n--- %s ---\n' "$md"; mdadm --detail "$md" 2>&1 || :
  done
  ((found==1)) || warn 'No md block devices found.'
}
show_md_members() {
  section 'RAID member assignments'
  if has mdadm; then
    local md
    for md in /dev/md[0-9]*; do
      [[ "$md" =~ ^/dev/md[0-9]+$ && -b "$md" ]] || continue
      printf '\n%s\n' "$md"; mdadm --detail "$md" 2>&1 | grep -E 'Raid Level|Raid Devices|Active Devices|Failed Devices|Array UUID|Device Role|/dev/|State :' || :
    done
  fi
  if [[ -d /sys/block ]]; then
    local d slave
    for d in /sys/block/md[0-9]*; do
      [[ -d "$d" ]] || continue
      printf '\n%s members: ' "${d##*/}"
      for slave in "$d"/slaves/*; do [[ -e "$slave" ]] && printf '%s ' "${slave##*/}"; done
      printf '\n'
    done
  fi
}
show_resync() {
  section 'RAID rebuild / resync activity'
  show_or_unavailable /proc/mdstat
  local md
  for md in /sys/block/md[0-9]*; do
    [[ -d "$md/md" ]] || continue
    printf '%s: ' "${md##*/}"
    for x in sync_action degraded sync_completed; do [[ -r "$md/md/$x" ]] && printf '%s=%s ' "$x" "$(cat "$md/md/$x")"; done
    printf '\n'
  done
}
show_storage_configuration() {
  section 'Storage configuration summary'
  if has synostgpool; then
    info 'Synology pool management binary detected (not invoking mutation-capable update/cleanup).'
  fi
  show_volume_info
  show_mdstat
}
show_pool_detail() {
  section 'Storage pool information from DSM space table (read-only)'
  if ! has python3; then warn 'python3 unavailable; cannot safely parse DSM table'; return 0; fi
  python3 - <<'PY'
import json
p='/run/space/space_table'
try:
    with open(p,'r') as f: pools=json.load(f)
    if not isinstance(pools,list): raise ValueError('unexpected table format')
    for obj in pools:
        if not isinstance(obj,dict): continue
        print('Pool:',obj.get('id','?'),'Path:',obj.get('space_path','?'),'Missing:',obj.get('missing','?'))
        for md in obj.get('raids',[]):
            if isinstance(md,dict):print('  RAID:',md.get('md_path','?'), 'level:',md.get('level_str','?'),'members:',len(md.get('devs',[])))
except Exception as e:
    print('Storage pool metadata read unavailable:',e)
PY
}
show_degraded() {
  show_md_health_summary
  info 'Check member roles and populated bays before interpreting configured-member gaps as disk failures.'
}
show_topology() {
  show_md_members
  section 'Block-device topology'
  if has lsblk; then lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT 2>&1 || :; else warn 'lsblk unavailable'; fi
  if has dmsetup; then dmsetup ls --tree 2>&1 || :; fi
}
