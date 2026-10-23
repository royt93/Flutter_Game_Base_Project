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
- [ ] Widget tests, showcase host and device smoke if safe device available.
- [ ] Linux + Flutter 3.35.1 goldens, full suites, analyzers, API check, gates and CI.
