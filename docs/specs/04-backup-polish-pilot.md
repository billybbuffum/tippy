# Spec 04: Backup bundle, polish and the pilot

**Goal:**
- one backup holds everything (journal, rewards, Wander);
- restoring shows what will change and applies all of it or nothing;
- the app is polished enough for a two-week pilot on both phones.

**Depends on:** specs 01, 02 and 03 merged. **Parallel with:** 05.
**Read first:** [specs README](./README.md) contract 5, [`architecture.md`](../architecture.md) §9.

## Backup bundle

### Format (v2)

```json
{
  "format": "tippy-backup",
  "version": 2,
  "exportedAt": "2026-11-19T18:00:00Z",
  "app": { "version": "0.2.0", "build": "57" },
  "journal": { …JournalCodec output… },
  "rewards": { …RewardsCodec output… },
  "wander": { …WanderCodec output… }
}
```

- **A v1 backup** (today's export, a bare journal) must still restore. It's detected by the missing `format` key;
  only the journal is replaced, and rewards and Wander are then re-synced from it.
- **`rewards` and `wander` are optional** in the file. If one is missing, that context is rebuilt by syncing from
  the restored journal (awards inside the back-fill window come back; older ones can't).
- **A newer `version` is refused** with a clear message.

### Where it lives

The bundle spans all three contexts, so it gets a small integration package rather than living in any one of them:

- **`Modules/TippyBackup`** (Foundation only, Swift 6 mode) depends on `TippyModeration`, `TippyRewards` and
  `TippyWander`. It holds the format and the preview, and is unit-tested with `swift test`:
  - a v2 round trip;
  - decoding a v1 bare journal;
  - missing `rewards` or `wander`;
  - refusing a newer version;
  - preview counts.

  It is not a bounded context and owns no rules of its own. Add it to the architecture doc's context table as
  "integration", and to the CI test step.
- **`Sources/Tippy/Model/BackupService.swift`** is the application layer. It writes the export file and applies a
  restore atomically through the three stores (the flow below).

```swift
// Modules/TippyBackup
public struct BackupBundle: Equatable, Sendable {
    public var journal: Journal
    public var rewards: RewardsLedger?
    public var wander: WanderState?
}

public enum BackupFormat {
    public static func encode(_ bundle: BackupBundle, exportedAt: Date, appVersion: String, build: String) throws -> Data
    public static func decode(_ data: Data) throws -> BackupBundle   // handles v1 and v2
}

public struct RestorePreview: Equatable, Sendable {   // shown before anything changes
    public struct Side: Equatable, Sendable {
        public var daysLogged: Int
        public var drinks: Int
        public var reflections: Int
        public var coins: Int
        public var decorations: Int
        public var pets: Int
        public var firstDay: LocalDate?
        public var lastDay: LocalDate?
    }
    public var current: Side
    public var backup: Side
    public init(current: BackupBundle, backup: BackupBundle)
}
```

### Restore flow

1. **Choose a file:** Settings > Backup > "Restore from a backup" (`import-backup-button`) opens the file picker.
2. **Preview:** a sheet (`restore-preview`) compares this phone and the backup side by side: days logged, date
   range, drinks, reflections, coins, decorations and pets, with "Replace everything on this phone"
   (`restore-confirm-button`) and Cancel.
3. **Apply atomically:**
   - encode all three files to temporary paths;
   - then move each into place, first backing up the current files to `*.before-restore.json`;
   - if any step fails, roll back from those and show the error;
   - on success, delete the `.before-restore` files and reload every model from its store.

   Models must expose `reload()` for this, so no model keeps stale state.
4. **Duplicate IDs:** if a restore is applied twice, the second replaces the first wholesale. There's no merging;
   say so in the preview text.

### Export

- `exportBackup()` moves from `JournalModel` to the backup service, producing v2.
- The file is named `Tippy backup 2026-11-19.json`.
- Above the share button, add a line: "Backups include your notes and reflections. Keep them somewhere private."
  (`export-privacy-note`).

## Polish

- **Dynamic Type:** check the largest accessibility size on Home, the log sheet, the recap, the shop and the Wander.
  Nothing clips that matters, and scroll where needed.
- **VoiceOver:** every sprite either has a meaningful label (the pet: "Sprout is happy") or is hidden. The camp
  slots, trail nodes and shop items read sensibly.
- **Reduce Motion:** every loop shows still poses, and transitions fade.
- **Dark mode:** the scene and cards read well. Sprites stay as they are, and backgrounds adapt.
- **Empty and first states:** no blank screens, with a friendly line everywhere.
- **Version:** bump `CFBundleShortVersionString` to `0.2.0` for the pilot.

## Smoke scenarios

| Scenario | Seed | Shows |
|---|---|---|
| `restore-preview` | a `restorable` seed: the demo app holds a bundled synthetic v2 backup at a temp path that the importer is pointed at in demo mode | Settings > Restore, the preview shows both sides, Cancel; nothing changed. |
| `restore-apply` | `restorable` | Restore, confirm; Home shows the backup's pet and coin balance. |

(In demo mode, the file picker is replaced by a "Use demo backup" button behind `UISmokeMode.isActive`, because
XCUITest can't drive the system file picker reliably.)

## Pilot (two weeks, both phones)

**Before:**
- merge;
- install from the Pages link on both phones;
- export a backup on day 1 to confirm the round trip;
- turn on the reminder.

**During:** use it daily. Write notes in a private place (not GitHub): what was confusing, what felt like nagging,
what she wanted to buy or find next.

**Check:**

| Question | Signal |
|---|---|
| Is logging quick? | A routine check-in takes under about 30 seconds |
| Does she come back? | Days logged per week |
| Did decorating or pets pull her back? | Ask her |
| Did anything feel like guilt? | Ask her |
| Did any data get lost? | Update over a previous build, restore a backup, relaunch |

**After:**
- turn the feedback into issues;
- tune the economy constants (`EarningRules`, prices, `hatchAfterCheckIns`, trail steps) in one PR, with tests
  updated;
- decide on the plan's "revisit after the pilot" items.

## Acceptance

- Restoring a v2 backup on a fresh install brings back every log, reflection, coin, decoration and pet.
- Restoring a v1 backup brings back the journal and rebuilds the rest.
- A failed restore leaves the phone exactly as it was.
- No personal data in the repo, issues or CI artifacts.
