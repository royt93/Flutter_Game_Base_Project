# 0.6.3 intake checklist

## Release-cycle retrospective (Waves 30–33)
- Keep Flutter test selectors exact. `--name='Wave 2'` can match every Wave 20–29 test; Wave33 was initially invoked with a selector that matched zero tests. Check log for the named test and `All tests passed`, not only build/exit wrapper output.
- Flutter Driver does not support release mode on Android. `flutter test --release` is unsupported; use `flutter drive --profile` for supported performance-like mode. For actual release UI inspection, use a temporary app harness via `flutter run --release` and inspect rendered widget tree/log output; delete the harness afterwards.
- Run CI monitors keyed to full commit SHA. One emulator smoke timed out after 20 minutes without test progress while the prior run passed; a later commit's consumer-smoke passed. Treat as unexplained infrastructure/test-runner issue unless logs identify a code failure; don't retry blindly.
- Linux golden workflow rewrites lockfiles on its branch. Import only explicitly named new/changed PNGs, close its generated PR without merging, and verify lockfiles untouched.
- One TECNO boot measurement was 108.7s under high host/device load; subsequent repeated measurements were stable around 31–34s and within the 60s policy. Preserve raw samples and environment; don't update baseline or relax policy from an outlier.
- Preserve the distinction between UI/callback wiring evidence and real backend delivery, reward payout, replay authenticity, or analytics transport.


Start only when consumer/partner feedback, issue, or measured regression gives concrete need. Checklist does not authorize implementation or release.

- [ ] Record request, affected user flow, impact, reproducible steps and expected behavior.
- [ ] Verify against current `main` and 0.6.2; search existing core services, widget exports, showcase and done specs for overlap.
- [ ] State smallest scope and acceptance criteria; identify data-loss, privacy/security, accessibility and performance risks.
- [ ] Define focused unit/widget/integration coverage and required evidence before changing code.
- [ ] Confirm API compatibility and whether change belongs in package core, reusable widget, or example only.
- [ ] Keep all code on `main`; do not create branches/worktrees.
- [ ] After scope approval, implement minimum change, test and run analyzers, API gate and relevant quality gates.
- [ ] Set version to 0.6.3 only for an approved release candidate; update CHANGELOG with verified evidence.
- [ ] Commit/push and require green CI; publish golden baselines through Linux workflow only when goldens changed.
- [ ] Run clean-tree `dart pub publish --dry-run`; obtain explicit approval before tag/publish.
