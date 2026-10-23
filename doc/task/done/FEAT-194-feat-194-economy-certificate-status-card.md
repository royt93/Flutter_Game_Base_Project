---
id: FEAT-194
title: EconomyCertificateStatusCard — Safe verification outcome display
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Session and Trust Inspection (Wave 26)
---

## Phạm vi
- Caller maps `EconomyCertificateVerification.status` to unverified/valid/tampered/clockSuspicious and supplies optional safe summary.
- Widget never receives balances, certificate JSON, HMAC secret or ledger data; valid copy means signature checks out, not that player is trustworthy.
- Optional verify-again callback has in-flight lock and generic error copy.

## Kiểm chứng
- [x] Widget tests, showcase host, root 3,374 and example 310 suites, analyzers, API compatibility and 5 quality gates pass.
- [x] 28 Linux + Flutter 3.35.1 PNG baselines imported from workflow 39908030941; lockfiles untouched.
- [x] 2026-10-23: TECNO KJ7 passes 'Wave 26: session timeline and trust summary on device' in `example/integration_test/app_boot_test.dart` with `E2E_TEST=true`. UI/callback fixture evidence only, not real certificate verification.
- [x] CI 39908353321 (analyze-test, quality-gate, consumer-smoke) passes on `f1b32df`.
