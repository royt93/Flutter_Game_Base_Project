# 0.6.3 intake checklist

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
