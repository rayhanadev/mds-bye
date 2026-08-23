#!/bin/bash
# Report whether the disable-indexers enforcement is in place and whether
# anything crept back. Read-only: this script never changes system state.
#
# Exit 0 if every check passes, 1 if any check fails.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.rayhanadev.disable-indexers"
# Under sudo, id -u is 0 and gui/0 is root's domain, not the user's. Fall back to
# SUDO_UID so the user-domain checks inspect the right session either way.
UID_NUM="${SUDO_UID:-$(id -u)}"
GUI="gui/${UID_NUM}"
FM="/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels"
INDEXER_RE='mds_stores|mdworker|corespotlightd|spotlightknowledged|photoanalysisd|mediaanalysisd|knowledge-agent|duetexpertd'

if [ -t 1 ]; then
  B=$'\e[1m'; D=$'\e[2m'; G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; N=$'\e[0m'
else
  B=''; D=''; G=''; R=''; Y=''; N=''
fi

failed=0
section() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
pass()    { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
fail()    { printf '  %s✗%s %s\n' "$R" "$N" "$1"; failed=1; }
skip()    { printf '  %s?%s %s\n' "$Y" "$N" "$1"; }
note()    { printf '    %s%s%s\n' "$D" "$1" "$N"; }

# Pull a job-label array out of one of the sweep scripts, ignoring comments.
labels_in() {
  sed -n "/^$2=(/,/^)/p" "$1" 2>/dev/null \
    | sed 's/#.*//' \
    | grep -oE 'com\.apple\.[A-Za-z0-9_.-]+'
}

# Compare an expected label list against a launchctl print-disabled dump.
report_disabled() {
  local name="$1" expected="$2" dump="$3" missing=() total=0 label
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    total=$((total + 1))
    grep -qF "\"${label}\" => disabled" <<<"$dump" || missing+=("$label")
  done <<<"$expected"

  if [ "${#missing[@]}" -eq 0 ]; then
    pass "${name}: ${total}/${total} disabled"
  else
    fail "${name}: $((total - ${#missing[@]}))/${total} disabled"
    printf '%s\n' "${missing[@]:0:6}" | while IFS= read -r label; do note "not disabled: $label"; done
    [ "${#missing[@]}" -gt 6 ] && note "and $(( ${#missing[@]} - 6 )) more"
  fi
}

section 'Enforcement jobs'
if launchctl print "${GUI}/${LABEL}" >/dev/null 2>&1; then
  pass "user agent loaded (${LABEL})"
else
  fail "user agent not loaded (${LABEL})"
fi
if sudo -n launchctl print "system/${LABEL}" >/dev/null 2>&1; then
  pass "system daemon loaded (${LABEL})"
elif sudo -n true 2>/dev/null; then
  fail "system daemon not loaded (${LABEL})"
else
  skip "system daemon state needs sudo: sudo launchctl print system/${LABEL}"
fi

section 'Spotlight'
spotlight="$(mdutil -s / 2>&1)"
if grep -qi 'disabled' <<<"$spotlight"; then
  pass "indexing off on /"
else
  fail "indexing on: ${spotlight#*	}"
fi

section 'Disabled jobs'
user_dump="$(launchctl print-disabled "user/${UID_NUM}" 2>/dev/null)"
report_disabled 'user domain' "$(labels_in "${REPO}/scripts/disable-indexers.sh" USER_JOBS)" "$user_dump"
sys_dump="$(sudo -n launchctl print-disabled system 2>/dev/null)"
if [ -n "$sys_dump" ]; then
  report_disabled 'system domain' "$(labels_in "${REPO}/scripts/disable-indexers-system.sh" SYS_JOBS)" "$sys_dump"
else
  skip 'system domain needs sudo: sudo launchctl print-disabled system'
fi

section 'Running indexers'
running="$(ps -Ao pid=,pcpu=,comm= | grep -iE "$INDEXER_RE" | grep -v grep)"
if [ -z "$running" ]; then
  pass 'none running'
else
  fail "$(wc -l <<<"$running" | tr -d ' ') running"
  while IFS= read -r line; do note "$line"; done <<<"$running"
fi

section 'Generative-model tombstone'
if [ ! -d "$FM" ]; then
  fail 'directory missing; models can download again'
elif ! ls -ldO "$FM" | grep -q 'schg'; then
  fail 'directory present but not immutable (schg flag cleared)'
elif [ "$(du -sk "$FM" 2>/dev/null | awk '{print $1}')" -gt 1024 ]; then
  fail "directory holds $(du -sh "$FM" 2>/dev/null | awk '{print $1}') of model data"
else
  pass 'empty and immutable'
fi

printf '\n'
if [ "$failed" -eq 0 ]; then
  printf '%s%sAll checks passed.%s\n' "$B" "$G" "$N"
else
  printf '%s%sSome checks failed.%s Run ./install.sh to re-apply.\n' "$B" "$R" "$N"
fi
exit "$failed"
