# roy_casual_kit 0.9.0: release notes (DRAFT, not published)

Draft for the GitHub release body. Nothing here has been tagged or published.
The authoritative list is `CHANGELOG.md` (section 0.9.0).

0.9.0 is a save-safety release. Because 0.x treats a minor bump as breaking,
`^0.8.0` does not resolve to 0.9.0; use `roy_casual_kit: ^0.9.0` once published.

## Save safety

- An unusable save is no longer destroyed by the next `save()`.
  `VersionedJsonStore.save()` (and a `syncWith` that replaces the local copy)
  first copies a raw value that cannot be read (corrupt JSON, a NEWER schema,
  a failing migration) to `<key>.bak`. One backup is kept. A readable save is
  never backed up. Before this, a player who downgraded the app, or hit a
  migration bug, lost their only copy on the next save.
- New `VersionedJsonStore.hasBackup`, `loadBackup()`, `restoreBackup()` and
  `backupKey`. `loadBackup()` applies the same schema policy as `load()`.
  `restoreBackup()` replaces the live save and clears the backup, so ask the
  player first when a save exists.
- `syncWith`: a cloud `syncedAtMs` more than 24 hours ahead of the device clock
  (`VersionedJsonStore.maxCloudClockSkewMs`) no longer wins last-write-wins when
  a local save exists. Before, it overwrote honest local saves on every sync.
  Your `onConflict` handler still sees the real timestamp. With no local save,
  the cloud copy still restores.
- `SaveMigrationRegistry` throws `SaveMigrationException` at construction when
  the step chain has a gap before `currentVersion`. Before, it only failed when
  an old save was loaded. If you build a registry with a missing hop, fix the
  chain.

## Smaller changes

- `EconomyWallet` per-balance cap (2,147,483,647) is now documented in the
  README.
- Example showcase: the `TooltipBubble` demo wraps instead of overflowing at 2.0
  text scale.

## What is and is not verified

- Host tests (root and example), analyzer, API compatibility and the five
  quality-gate checks pass locally, and CI (all jobs) is green on the release
  commit `5be64e06`.
- The behaviors above were reproduced by throwaway tests before the fixes, and
  the new tests fail when the fix is removed (mutation checked).
- Not covered: a device run of the new save paths (host tests only), and no UI
  in the example for restoring a backup.
- Platforms: Android and iOS only.
