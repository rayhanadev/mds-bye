#!/bin/bash
# Undo everything install.sh did and hand the machine back to Apple.
#
# This removes the enforcement jobs, re-enables every launchd job the scripts
# disabled, drops the immutable-directory tombstone, and turns Spotlight
# indexing back on. A full reindex will follow and will be loud for a while.
#
# It CANNOT restore the AssetsV2 model packs that were deleted -- macOS has to
# redownload those, which only happens once Apple Intelligence / Siri are turned
# back on in System Settings.
set -uo pipefail

UID_NUM="$(id -u)"
GUI="gui/${UID_NUM}"

USER_JOBS=(
  com.apple.corespotlightd com.apple.corespotlightservice com.apple.managedcorespotlightd
  com.apple.mdworker.application com.apple.mdworker.mail com.apple.mdworker.shared
  com.apple.mdworker.single.arm64 com.apple.mdworker.single.x86_64 com.apple.mdworker.sizing
  com.apple.metadata.mdbulkimport com.apple.metadata.mdflagwriter com.apple.metadata.mdwrite
  com.apple.knowledge-agent com.apple.knowledgeconstructiond com.apple.siriknowledged
  com.apple.spotlightknowledged com.apple.spotlightknowledged.importer
  com.apple.spotlightknowledged.updater com.apple.Siri.agent com.apple.Spotlight
  com.apple.duetexpertd com.apple.assistantd com.apple.assistant_service
  com.apple.assistant_cdmd com.apple.siriactionsd com.apple.siriappintentsd
  com.apple.siriinferenced com.apple.sirittsd com.apple.SiriTTSTrainingAgent
  com.apple.campo com.apple.generativeexperiencesd com.apple.intelligencecontextd
  com.apple.intelligenceflowd com.apple.intelligenceplatformd com.apple.intelligencetasksd
  com.apple.visualintelligenced com.apple.GenerativeFunctions.agentstored
  com.apple.ModelCatalogAgent com.apple.photolibraryd com.apple.cloudphotod
  com.apple.photoanalysisd com.apple.CloudPhotosConfiguration
  com.apple.mediastream.mstreamd com.apple.mediaanalysisd
)

SYS_JOBS=(
  com.apple.metadata.mds com.apple.metadata.mds.index com.apple.metadata.mds.index.readonly
  com.apple.metadata.mds.scan com.apple.metadata.mds.spindump com.apple.msrpc.mdssvc
  com.apple.diagnosticextensions.osx.spotlight.helper
  com.apple.modelcatalogd com.apple.modelmanagerd
)

echo "==> Stopping and removing the enforcement jobs"
LABEL="com.rayhanadev.disable-indexers"
launchctl bootout "${GUI}/${LABEL}"    >/dev/null 2>&1
sudo launchctl bootout "system/${LABEL}" >/dev/null 2>&1
rm -f "${HOME}/Library/LaunchAgents/${LABEL}.plist" "${HOME}/.local/sbin/disable-indexers.sh"
sudo rm -f "/Library/LaunchDaemons/${LABEL}.plist" /usr/local/libexec/disable-indexers-system.sh

echo "==> Re-enabling user jobs"
for job in "${USER_JOBS[@]}"; do
  launchctl enable "${GUI}/${job}" >/dev/null 2>&1
done

echo "==> Re-enabling system jobs"
for job in "${SYS_JOBS[@]}"; do
  sudo launchctl enable "system/${job}" >/dev/null 2>&1
done

echo "==> Releasing the generative-model tombstone"
FM="/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels"
sudo chflags -R noschg,nouchg "$FM" 2>/dev/null
sudo rmdir "$FM" 2>/dev/null

echo "==> Re-enabling Spotlight indexing (this triggers a full reindex)"
sudo mdutil -a -i on  >/dev/null 2>&1
sudo mdutil -a -E     >/dev/null 2>&1

echo "==> Reverting user prefs"
defaults delete com.apple.lookup.shared LookupDisabled                      2>/dev/null
defaults delete com.apple.Siri UserHasDeclinedEnable                        2>/dev/null
defaults delete com.apple.Siri VoiceTriggerUserEnabled                      2>/dev/null
defaults delete com.apple.assistant.support "Assistant Enabled"             2>/dev/null
defaults delete com.apple.Spotlight orderedItems                            2>/dev/null
defaults delete com.apple.HIToolbox AppleDictationAutoEnable                2>/dev/null
defaults delete com.apple.gms.availability "com.apple.gms.availability.wasAvailable" 2>/dev/null
defaults delete com.apple.CloudSubscriptionFeatures.cache GMOptIn           2>/dev/null

echo
echo "Done. Reboot so every re-enabled job bootstraps cleanly."
echo "Deleted AssetsV2 model packs are NOT restored -- turn Apple Intelligence"
echo "and Siri back on in System Settings and macOS will redownload them."
