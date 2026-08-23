# mds-bye

Keeps Spotlight, Siri, Photos analysis, and Apple Intelligence disabled on macOS across updates.

Two launchd jobs re-apply a disable sweep at load and every 300 seconds, one in the system domain and one in `gui/$UID`. macOS updates revert `mdutil -a -i off` and clear `launchctl disable`; the sweep re-applies both.

> [!WARNING]
> Partly irreversible. It deletes Spotlight indexes, unsubscribes from Apple's asset downloads, and deletes Siri and Apple Intelligence model packs. `uninstall.sh` restores the daemons and settings but cannot restore deleted model packs.

## Requirements

- macOS 26 (Darwin 27) on Apple silicon. Other releases are untested and job labels differ between them
- An admin account
- System Integrity Protection (SIP) Filesystem Protections disabled, for the model pack removal only. See [SIP](#sip)

## Usage

```bash
git clone https://github.com/rayhanadev/mds-bye.git && cd mds-bye
./install.sh      # deploy both jobs, prompts for sudo
./status.sh       # exits 0 if every check passes
./uninstall.sh    # full revert, reboot afterward
```

`install.sh` is idempotent. Re-run it after editing the scripts to redeploy.

```console
$ ./status.sh
Enforcement jobs
  ✓ user agent loaded (com.rayhanadev.disable-indexers)
  ✓ system daemon loaded (com.rayhanadev.disable-indexers)

Spotlight
  ✓ indexing off on /

Disabled jobs
  ✓ user domain: 44/44 disabled
  ✓ system domain: 9/9 disabled

Running indexers
  ✓ none running

Generative-model tombstone
  ✓ empty and immutable

All checks passed.
```

## Installed files

| | User half | System half |
|---|---|---|
| Plist | `~/Library/LaunchAgents/com.rayhanadev.disable-indexers.plist` | `/Library/LaunchDaemons/com.rayhanadev.disable-indexers.plist` |
| Script | `~/.local/sbin/disable-indexers.sh` | `/usr/local/libexec/disable-indexers-system.sh` |
| Domain | `gui/$UID` | `system` |

Both plists set `RunAtLoad`, `StartInterval 300`, and `Nice 20`.

## What it disables

53 launchd jobs, 44 in `gui/$UID` and 9 in `system`. Each gets `launchctl bootout` then `launchctl disable`. The lists are the `USER_JOBS` and `SYS_JOBS` arrays in the two scripts.

| Group | Domain | Jobs |
|---|---|---|
| Spotlight and metadata | user | `mdworker` fleet, `metadata.*`, `corespotlightd`, `Spotlight` |
| Knowledge graph | user | `knowledge-agent`, `spotlightknowledged`, `siriknowledged`, `duetexpertd` |
| Siri and Apple Intelligence | user | `assistantd`, `siri*`, `intelligence*d`, `generativeexperiencesd` |
| Photos and media analysis | user | `photolibraryd`, `photoanalysisd`, `cloudphotod`, `mediaanalysisd` |
| Spotlight server | system | `metadata.mds*`, `msrpc.mdssvc` |
| Apple Intelligence | system | `modelcatalogd`, `modelmanagerd` |

It also writes preferences that stop the UI from re-arming anything: Siri and dictation off, `LookupDisabled`, all 22 `com.apple.Spotlight` result categories off, and the Apple Intelligence opt-in flags cleared.

## What it deletes

- **Spotlight indexes**: `.Spotlight-V100` on every volume, plus `/private/var/db/{Spotlight,Spotlight-V100,mds}`. Derived data, rebuilt if you re-enable indexing
- **Asset subscriptions**: rows in `UAFAssetSubscriptions.db` for the model catalog, Siri, translation, and speech packs. Without this the packs refetch
- **Model packs**: 44 paths under `/System/Library/AssetsV2`. `uninstall.sh` cannot restore these; macOS refetches them only after you re-enable Apple Intelligence and Siri in System Settings
- **Foundation model bundle**: replaced with an empty directory carrying `schg,uchg`, so the download cannot land

## SIP

`/System/Library/AssetsV2` carries the `restricted` flag, which gates two steps:

| Step | Stock SIP | Filesystem Protections off |
|---|---|---|
| launchd disabling, `mdutil`, `pkill`, prefs | ✅ | ✅ |
| Spotlight index deletion | ✅ | ✅ |
| `assetsubscriptiond` unsubscribe | ✅ | ✅ |
| Model pack deletion | ❌ | ✅ |
| `chflags` tombstone | ❌ | ✅ |

Under stock SIP the gated steps become no-ops and everything else still works.

## Customizing

Job lists are bash arrays at the top of each script. Edit them, then re-run `./install.sh`. `uninstall.sh` keeps its own copy of both arrays, so update it too.

Deliberate exceptions and known gaps are documented as comments at the point in the scripts where they apply.

## License

MIT. See [LICENSE](LICENSE). No affiliation with Apple.
