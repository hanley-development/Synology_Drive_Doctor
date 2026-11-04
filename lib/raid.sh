#!/usr/bin/env bash
# RAID, storage and md metadata readbacks. No mdadm mutations.
show_mdstat() { section 'Linux md RAID: /proc/mdstat'; show_or_unavailable /proc/mdstat; }
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
  section 'Current RAID degradation overview'
  local found=0 d state
  for d in /sys/block/md[0-9]*; do
    [[ -r "$d/md/degraded" ]] || continue
    state=$(cat "$d/md/degraded")
    printf '%s: degraded=%s\n' "${d##*/}" "$state"
    [[ "$state" == '0' ]] || found=1
  done
  [[ "$found" == 0 ]] && info 'No current degraded members reported by available md sysfs counters.' || warn 'One or more arrays show degradation.'
  info 'Read the corresponding mdadm member list; never infer an empty fifth bay is a fault.'
}
show_topology() {
  show_md_members
  section 'Block-device topology'
  if has lsblk; then lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT 2>&1 || :; else warn 'lsblk unavailable'; fi
  if has dmsetup; then dmsetup ls --tree 2>&1 || :; fi
}
