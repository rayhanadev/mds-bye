#!/bin/bash
# System half of the enforcement pair. Runs as root from
# com.rayhanadev.disable-indexers (LaunchDaemon), at load and every 300s.
#
# Handles the jobs that need root: mds and its index daemons, the SMB Spotlight
# server, and the Apple Intelligence model catalog/runtime. The gui/$UID jobs are
# handled by disable-indexers.sh.
#
# set +e and the unconditional exit 0 are deliberate: a non-zero exit makes
# launchd throttle or unload the job, which would end the enforcement.
#
# SIP: the AssetsV2 steps below (model pack deletion and the chflags tombstone)
# require System Integrity Protection Filesystem Protections to be disabled,
# because /System/Library/AssetsV2 carries the restricted flag. Under stock SIP
# they fail silently and every other step still works.
set +e

SYS_JOBS=(
  com.apple.metadata.mds
  com.apple.metadata.mds.index
  com.apple.metadata.mds.index.readonly
  com.apple.metadata.mds.scan
  com.apple.metadata.mds.spindump
  com.apple.msrpc.mdssvc
  com.apple.diagnosticextensions.osx.spotlight.helper
  com.apple.modelcatalogd
  com.apple.modelmanagerd
)

for job in "${SYS_JOBS[@]}"; do
  launchctl bootout "system/${job}" >/dev/null 2>&1
  launchctl disable "system/${job}" >/dev/null 2>&1
done

mdutil -a -i off >/dev/null 2>&1
mdutil -a -d >/dev/null 2>&1
for vol in / /System/Volumes/Data /System/Volumes/Preboot /System/Volumes/VM /System/Volumes/Update; do
  [ -d "$vol" ] || continue
  mdutil -i off "$vol" >/dev/null 2>&1
  mdutil -d "$vol" >/dev/null 2>&1
done

killall mds mds_stores mdworker mdworker_shared corespotlightd modelmanagerd modelcatalogd >/dev/null 2>&1

rm -rf \
  /.Spotlight-V100 \
  /System/Volumes/Data/.Spotlight-V100 \
  /System/Volumes/Preboot/.Spotlight-V100 \
  /private/var/db/Spotlight \
  /private/var/db/Spotlight-V100 \
  /private/var/db/mds \
  /System/Volumes/Data/private/var/db/Spotlight \
  /System/Volumes/Data/private/var/db/Spotlight-V100 \
  /System/Volumes/Data/private/var/db/mds

# Unsubscribe before deleting. Without this, assetsubscriptiond simply refetches
# every pack removed below on the next network idle.
DB="/private/var/db/assetsubscriptiond/UAFAssetSubscriptions.db"
if [ -f "$DB" ]; then
  sqlite3 "$DB" "DELETE FROM Subscriptions WHERE k0 = 'model-catalog' OR k0 = 'siritts' OR k0 = 'com.apple.summarizationkit' OR k0 LIKE 'com.apple.siri.%' OR k0 = 'com.apple.translationd.uaf' OR k0 = 'com.apple.TelephonyUtilities' OR k0 = 'com.apple.search.queryparser';" >/dev/null 2>&1
  sqlite3 "$DB" "DELETE FROM SystemAssetSetUsages WHERE k0 LIKE 'com.apple.MobileAsset.UAF.FM.%' OR k0 LIKE 'com.apple.MobileAsset.UAF.Siri%' OR k0 LIKE 'com.apple.MobileAsset.UAF.Photos%' OR k0 LIKE 'com.apple.MobileAsset.UAF.Translation%' OR k0 LIKE 'com.apple.siri.%' OR k0 = 'com.apple.modelcatalog' OR k0 = 'com.apple.sequoia.asset' OR k0 = 'com.apple.summarizationkit' OR k0 = 'com.apple.speech.automaticspeechrecognition' OR k0 = 'com.apple.search.queryparser' OR k0 = 'com.apple.search.queryparser.overrides' OR k0 = 'com.apple.MobileAsset.UAF.Shortcuts.Generator' OR k0 = 'com.apple.MobileAsset.UAF.Handwriting.Synthesis' OR k0 = 'com.apple.parsec.sba';" >/dev/null 2>&1
fi

# Siri / translation / speech / Photos Relive / AI-adjacent UAF packs.
# Each family is removed at three layers: the payload, its locks/ entry under
# com.apple.UnifiedAssetFramework, and its manifests/ entry including
# manifests/staged/. Deleting only the payload leaves a manifest that triggers
# a refetch.
rm -rf \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Siri_Understanding \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Siri_TextToSpeech \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Siri_UnderstandingASRHammer \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Siri_DialogAssets \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Siri_FindMyConfigurationFiles \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Translation_MMAssets \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Translation_Assets \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Photos_SpatialPhotosRelive \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_SearchQueryUnderstanding \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_SearchQueryUnderstandingOverrides \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Shortcuts_Generator \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_SafariBrowsingAssistant \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_SummarizationKitConfiguration \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_Handwriting_Synthesis \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_TKModelMessages \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Visual \
  /System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Overrides \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.FM.Visual \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.FM.Overrides \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.Translation.MMAssets \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.Shortcuts.Generator \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.MobileAsset.UAF.Handwriting.Synthesis \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.siri.tts \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.siri.understanding \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.siri.dialog \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.siri.asr.hammer \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.siri.findmy \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.speech.automaticspeechrecognition \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.modelcatalog \
  /System/Library/AssetsV2/locks/com.apple.UnifiedAssetFramework/com.apple.sequoia.asset \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_FM_GenerativeModels \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_Siri_Understanding \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_Siri_TextToSpeech \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_Translation_MMAssets \
  /System/Library/AssetsV2/manifests/com_apple_MobileAsset_UAF_Photos_SpatialPhotosRelive \
  /System/Library/AssetsV2/manifests/staged/com_apple_MobileAsset_UAF_FM_GenerativeModels \
  /System/Library/AssetsV2/manifests/staged/com_apple_MobileAsset_UAF_Siri_Understanding \
  /System/Library/AssetsV2/manifests/staged/com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition \
  /System/Library/AssetsV2/manifests/staged/com_apple_MobileAsset_UAF_Translation_MMAssets \
  /System/Library/AssetsV2/manifests/staged/com_apple_MobileAsset_UAF_Photos_SpatialPhotosRelive

# The foundation-model bundle is the largest download, so block the path rather
# than delete it every tick: an empty directory carrying both immutable flags
# cannot be written into, renamed, or removed, so the downloader's writes fail
# at the filesystem layer. The 1 MB guard skips the delete when the tombstone is
# already in place and only re-asserts the flags.
FM="/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels"
if [ -e "$FM" ]; then
  used=$(du -sm "$FM" 2>/dev/null | awk '{print $1}')
  if [ "${used:-0}" -gt 1 ]; then
    chflags -R noschg,nouchg "$FM" 2>/dev/null
    rm -rf "$FM"
  fi
fi
if [ ! -d "$FM" ]; then
  mkdir -p "$FM"
fi
chflags schg,uchg "$FM" 2>/dev/null

exit 0
