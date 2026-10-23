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
- [ ] Reachable-device smoke (S24 Ultra not connected; TECNO foreground app was a benchmark and was not interrupted).
- [ ] Linux + Flutter 3.35.1 goldens for all four statuses × 7 variants.
- [ ] Full suites, analyzers, API compatibility, quality gates and CI.
