---
id: FEAT-200
title: SaveRestorePreviewPanel — Confirmed per-slot restore preview
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Analytics Queue and Save Restore Preview (Wave 28)
---

## Need
A signed multi-slot backup has a safe `RestorePreview`, but existing `BackupRestorePanel` restores the whole storage dump without a per-slot summary.

## Phạm vi
- Caller supplies slot name, last-played text and key count mapped from verified `RestorePreview`; no slot IDs, payload, signed bundle, secret or recovery-log details enter widget.
- Restore requires inline confirmation; copy says matching slot data is replaced and action cannot be undone. Cancel is callback-free.
- Busy/in-flight lock, stale preview invalidates confirmation, generic errors.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,395 and example 312 suites, analyzers, API compatibility and 5 quality gates pass.
- [x] 14 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39928480292; lockfiles untouched.
- [x] TECNO KJ7 (`115333744A005844`) integration smoke passes confirm/cancel and caller restore callback.
- [x] CI 39928814646 (analyze-test, quality-gate, consumer-smoke) passes on `c37e944`.
