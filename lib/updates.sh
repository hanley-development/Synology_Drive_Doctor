#!/usr/bin/env bash
# Optional, interactive integration updates. Checks are non-mutating network requests.
DOCTOR_REPO='https://github.com/hanley-development/Synology_Drive_Doctor'
UPSTREAM_REPO_API='https://api.github.com/repos/007revad/Synology_HDD_db/commits/main'
show_versions() {
  section 'Installed components'
  printf 'Drive Doctor: %s\n' "$SCRIPT_VERSION"
  printf 'Private repair plugin: '
  if fault_backend_check >/dev/null 2>&1; then printf 'installed (integrity verified)\n'; else printf 'not installed / not verified\n'; fi
  printf 'HDD DB: '
  [[ -r "$HDD_SCRIPT" ]] && printf 'installed\n' || printf 'missing\n'
  printf 'HDD DB source: %s\n' "$UPSTREAM_URL"
}
updates_check() {
  section 'Available upstream changes (read-only)'
  printf 'Drive Doctor repository target: %s\n' "$DOCTOR_REPO"
  if ! has curl || ! has python3; then warn 'curl and Python 3 required to query upstream metadata'; return 1; fi
  local response sha info
  response=$(curl -fsSL --connect-timeout 5 --max-time 15 -H 'Accept: application/vnd.github+json' "$UPSTREAM_REPO_API") || { warn 'Cannot reach upstream GitHub API'; return 1; }
  sha=$(printf '%s' "$response" | python3 -c 'import sys,json; x=json.load(sys.stdin); print(x.get("sha","unknown"))') || return 1
  printf 'Current 007revad main commit: %s\n' "$sha"
  if [[ -e "$HDD_ROOT/.git" ]]; then
    printf 'Installed checkout: '; git -C "$HDD_ROOT" rev-parse HEAD || :
  else warn 'Submodule not initialized or Git metadata unavailable.'; fi
  info 'Checking does not install or run anything. Compare the upstream changelog before an optional update.'
}
update_hdd_optional() {
  root_required || return 1
  interactive_required || return 1
  has git || { warn 'Git not installed; update the submodule from a Git-enabled workstation instead.'; return 1; }
  [[ -d "$DRIVE_DOCTOR_ROOT/.git" || -f "$DRIVE_DOCTOR_ROOT/.git" ]] || {
    warn 'This installation is not a Git checkout. Upgrade from a reviewed Drive Doctor release instead.'
    return 1
  }
  [[ -f "$HDD_SCRIPT" ]] || {
    warn 'HDD DB submodule not initialized; run git submodule update --init --recursive in your trusted checkout.'
    return 1
  }
  local gitlink old_sha remote_sha lines
  gitlink=$(git -C "$DRIVE_DOCTOR_ROOT" ls-files --stage -- integrations/Synology_HDD_db 2>/dev/null) || return 1
  [[ "$gitlink" == 160000\ * ]] || { warn 'HDD integration is not a tracked submodule; refusing update.'; return 1; }
  [[ -z "$(git -C "$HDD_ROOT" status --porcelain 2>/dev/null)" ]] || {
    warn 'Submodule has local edits; refusing update.'; return 1
  }
  old_sha=$(git -C "$HDD_ROOT" rev-parse HEAD) || return 1
  info "Currently installed upstream revision: $old_sha"
  info 'Fetching metadata/code from the original 007revad repository; not executing it.'
  git -C "$HDD_ROOT" fetch --no-tags origin main || { warn 'Upstream fetch failed'; return 1; }
  remote_sha=$(git -C "$HDD_ROOT" rev-parse FETCH_HEAD) || return 1
  if [[ "$remote_sha" == "$old_sha" ]]; then info 'Already at upstream main revision.'; return 0; fi
  printf '\nProposed update: %s -> %s\n' "$old_sha" "$remote_sha"
  git -C "$HDD_ROOT" --no-pager log --format='%h %cs %s' --max-count=12 "$old_sha..$remote_sha" || :
  printf '\nChanged files summary:\n'
  git -C "$HDD_ROOT" --no-pager diff --stat "$old_sha" "$remote_sha" || :
  warn 'A submodule update changes code installed in this checkout. Review upstream changes and pin the new commit in Drive Doctor before releasing.'
  confirm UPDATE_HDD_DB 'Check out this upstream revision in the submodule? No compatibility modifications will be executed.' || return 1
  git -C "$HDD_ROOT" checkout --detach "$remote_sha" || return 1
  info "Updated submodule checkout to $remote_sha"
  info 'The parent repository now has a changed gitlink. Review and commit that pointer to make the update reproducible.'
}
update_doctor_optional() {
  info 'Drive Doctor self-update is not enabled in this first release.'
  info "Review/download a release from $DOCTOR_REPO and install separately. No files changed."
}
update_fault_optional() {
  info 'Stale Pool-Fault updates are distributed with reviewed Drive Doctor releases only.'
  info 'Private plugins are updated separately by an administrator after review.'
}
update_history() { section 'Update history'; info 'Update history can be inspected with git log of the parent repository and submodule gitlink changes.'; }
show_update_preferences() {
  section 'Update preferences'
  printf 'Update checks: %s\nInstall policy: %s\n' "$UPDATE_CHECK" "$UPDATE_MODE"
  info 'No scheduled updates or automatic installations are performed by v0.2.0.'
}
