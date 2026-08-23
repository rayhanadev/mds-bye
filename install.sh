#!/bin/bash
# Install the disable-indexers enforcement pair: a user LaunchAgent and a system
# LaunchDaemon that each re-apply the disable sweep at load and every 5 minutes.
#
# Usage:  ./install.sh          (prompts for sudo when it needs root)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UID_NUM="$(id -u)"
GUI="gui/${UID_NUM}"
LABEL="com.rayhanadev.disable-indexers"

USER_SCRIPT="${HOME}/.local/sbin/disable-indexers.sh"
SYS_SCRIPT="/usr/local/libexec/disable-indexers-system.sh"
USER_PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
SYS_PLIST="/Library/LaunchDaemons/${LABEL}.plist"

echo "==> Installing user script -> ${USER_SCRIPT}"
mkdir -p "${HOME}/.local/sbin"
install -m 0755 "${REPO}/scripts/disable-indexers.sh" "${USER_SCRIPT}"

echo "==> Installing system script -> ${SYS_SCRIPT}"
sudo mkdir -p /usr/local/libexec
sudo install -o root -g wheel -m 0755 "${REPO}/scripts/disable-indexers-system.sh" "${SYS_SCRIPT}"

echo "==> Installing LaunchAgent -> ${USER_PLIST}"
mkdir -p "${HOME}/Library/LaunchAgents"
sed "s|__HOME__|${HOME}|g" "${REPO}/launchd/${LABEL}.agent.plist" > "${USER_PLIST}"
chmod 0644 "${USER_PLIST}"

echo "==> Installing LaunchDaemon -> ${SYS_PLIST}"
sudo install -o root -g wheel -m 0644 "${REPO}/launchd/${LABEL}.daemon.plist" "${SYS_PLIST}"

echo "==> Bootstrapping jobs"
launchctl bootout "${GUI}/${LABEL}"    >/dev/null 2>&1 || true
sudo launchctl bootout "system/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "${GUI}" "${USER_PLIST}"
sudo launchctl bootstrap system "${SYS_PLIST}"

echo
echo "Installed. Both jobs ran once at load and will re-run every 300s."
echo "Check with: ${REPO}/status.sh"
