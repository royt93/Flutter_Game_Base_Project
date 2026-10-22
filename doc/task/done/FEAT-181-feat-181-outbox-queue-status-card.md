---
id: FEAT-181
title: OutboxQueueStatusCard — Queue counts and caller-owned drain status
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Offline Delivery UI (Wave 21)
---

## Need
`OfflineOutboxService` exposes a persisted reactive queue but no reusable summary UI. Existing showcase prints queue identifiers and payload values; reusable UI must never receive those records.

## Scope
- Props: non-negative pending/manual-review counts, caller-mapped status `idle/draining/offline/error`, busy, optional async drain callback.
- No `OutboxItem`, payload, remote payload, idempotency key, network client or service reference.
- Offline/draining/busy blocks drain. Callback errors use generic copy only.

## DoD
- [x] Widget tests: count/status mapping, offline/busy gating, validation, double-submit and generic retry.
- [x] Showcase replaces raw queue/conflict payload display; FEAT-67 tests pass with online state before drain.
- [x] TECNO KJ7 smoke validates queue counts and drain UI in full flow.
- [x] Root tests (3,213 non-golden), example tests (305), analyzers, API and quality gates pass.
- [x] Linux + Flutter 3.35.1 golden matrix idle/offline/error × 7 committed in `ca0d654`; lockfiles unchanged.
- [x] CI `39790922224`: host tests, quality gates, consumer-smoke all pass.
