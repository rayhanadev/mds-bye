#!/bin/bash
# User half of the enforcement pair. Runs as the logged-in user from
# com.rayhanadev.disable-indexers (LaunchAgent), at load and every 300s.
#
# Why a separate user script: launchd registers the mdworker fleet, CoreSpotlight,
# Siri, and Photos analysis in gui/$UID. Only the logged-in user can disable those.
# mds and its index daemons live in the system domain and need root, so they are
# handled by disable-indexers-system.sh instead. One script cannot reach both.
#
# Why every failure is swallowed and the script always exits 0: a non-zero exit
# makes launchd throttle or unload the job, which would end the enforcement.
#
# Known gaps, deliberate:
#   suggestd (CoreSuggestions) is not disabled here. It idles at 0% CPU and does
#     not index the filesystem. Neuter it via the com.apple.suggestions domain
#     (AppCanShowSiriSuggestionsBlacklist, SiriCanLearnFromAppBlacklist) instead.
#   SpotlightSettingsIntentsExtension.appex is not disabled here. It loads only
#     when the Spotlight settings pane is opened and does no indexing.
set -euo pipefail

UID_NUM="$(id -u)"
GUI="gui/${UID_NUM}"

USER_JOBS=(
  com.apple.corespotlightd
  com.apple.corespotlightservice
  com.apple.managedcorespotlightd
  com.apple.mdworker.application
  com.apple.mdworker.mail
  com.apple.mdworker.shared
  com.apple.mdworker.single.arm64
  com.apple.mdworker.single.x86_64
  com.apple.mdworker.sizing
  com.apple.metadata.mdbulkimport
  com.apple.metadata.mdflagwriter
  com.apple.metadata.mdwrite
  com.apple.knowledge-agent
  com.apple.knowledgeconstructiond
  com.apple.siriknowledged
  com.apple.spotlightknowledged
  com.apple.spotlightknowledged.importer
  com.apple.spotlightknowledged.updater
  com.apple.Siri.agent
  com.apple.Spotlight
  com.apple.duetexpertd
  com.apple.assistantd
  com.apple.assistant_service
  com.apple.assistant_cdmd
  com.apple.siriactionsd
  com.apple.siriappintentsd
  com.apple.siriinferenced
  com.apple.sirittsd
  com.apple.SiriTTSTrainingAgent
  com.apple.campo
  com.apple.generativeexperiencesd
  com.apple.intelligencecontextd
  com.apple.intelligenceflowd
  com.apple.intelligenceplatformd
  com.apple.intelligencetasksd
  com.apple.visualintelligenced
  com.apple.GenerativeFunctions.agentstored
  com.apple.ModelCatalogAgent
  # com.apple.translationd - leave enabled: it is launch-on-demand (no indexing).
  # Disabling it makes Music/Alcove spin at ~90% CPU retrying the missing
  # com.apple.translation.text XPC service with no backoff.
  com.apple.photolibraryd
  com.apple.cloudphotod
  com.apple.photoanalysisd
  com.apple.CloudPhotosConfiguration
  com.apple.mediastream.mstreamd
  com.apple.mediaanalysisd
)

for job in "${USER_JOBS[@]}"; do
  launchctl bootout "${GUI}/${job}" >/dev/null 2>&1 || true
  launchctl disable "${GUI}/${job}" >/dev/null 2>&1 || true
done

# User prefs: Siri/Spotlight search off
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
defaults write com.apple.lookup.shared LookupDisabled -bool true
defaults write com.apple.Spotlight orderedItems -array \
  '<dict><key>enabled</key><false/><key>name</key><string>APPLICATIONS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_EXPRESSION</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_CONVERSION</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_DEFINITION</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>SYSTEM_PREFS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>DOCUMENTS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>DIRECTORIES</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>PRESENTATIONS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>SPREADSHEETS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>PDF</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MESSAGES</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>CONTACT</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>EVENT_TODO</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>IMAGES</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>BOOKMARKS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MUSIC</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MOVIES</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>FONTS</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_OTHER</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>SOURCE</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_WEBSEARCH</string></dict>' \
  '<dict><key>enabled</key><false/><key>name</key><string>MENU_SPOTLIGHT_SUGGESTIONS</string></dict>'
defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0
defaults write com.apple.gms.availability "com.apple.gms.availability.wasAvailable" -bool false
defaults write com.apple.CloudSubscriptionFeatures.cache GMOptIn -bool false

# launchctl bootout does not stop processes that launchd spawned on demand
# through XPC, so match them by executable path and kill them directly.
pkill -u "${UID_NUM}" -f '/usr/libexec/knowledge-agent' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f '/usr/libexec/siriknowledged' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f '/usr/libexec/spotlightknowledged' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f '/Support/corespotlightd' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f 'mdbulkimport' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f 'mdworker' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f 'siriinferenced' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f 'siriknowledged' >/dev/null 2>&1 || true
pkill -u "${UID_NUM}" -f 'duetexpertd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f '/System/Applications/Siri AI.app' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'CampoRemoteService' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'SiriTTSService.framework/sirittsd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'SiriTTSTrainingAgent' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'SiriAUSP' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'SiriSetupSettingsIntents' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'generativeexperiencesd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'intelligenceflowd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'intelligencecontextd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'intelligenceplatformd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'intelligencetasksd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'visualintelligenced' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'GenerativeExperiencesSafetyInferenceProvider' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f '/Support/photolibraryd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f '/Support/photoanalysisd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'cloudphotod' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'CloudPhotosConfiguration' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'mediaanalysisd' >/dev/null 2>&1 || true
pkill -9 -u "${UID_NUM}" -f 'mediastream.mstreamd' >/dev/null 2>&1 || true

exit 0
