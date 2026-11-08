---
id: DISC-02
title: "Diagnose consumer-smoke emulator cold-boot timeout"
type: discovery
layer: ci/android-emulator
priority: P2
effort: S
source: "User-selected CI investigation 2026-11-08"
---

## Goal

Determine why GitHub Actions `consumer-smoke` sometimes exceeds the emulator boot wait and whether a minimal workflow change is justified. Keep Flutter pinned at 3.41.9; do not increase timeouts or alter emulator config without evidence.

## Evidence so far

- CI run `42392120613` on `a26c9521`: `analyze-test` and `quality-gate` passed. `consumer-smoke` timed out in `Integration test on emulator` after 20 minutes.
- Three emulator setup observations in that job: APK built successfully; `adb` temporarily reported `Unable to connect to adb daemon on port: 5037`; `adb shell getprop sys.boot_completed` then polled repeatedly. One log reported emulator boot completion only after the action's timeout.
- CI run `42456145100` on `47e15efd`: `analyze-test` and `quality-gate` passed. APK built successfully; NDK 28.2 and CMake 3.22 were additionally installed; emulator runner installed API 34 emulator/system image, reported ADB disconnection, then boot completed only after the 20-minute action timeout.
- A prior `consumer-smoke` run `42392120613` retry and the above run have timed out, while earlier runs `42387567542` and `42374006248` passed. This is intermittent runner/setup behavior, not yet a proven code or dependency defect.
- CI run `42456145100` (final rerun after Stage A/B dependency upgrade): `analyze-test` and `quality-gate` passed; consumer app analyze/tests and APK build passed. Emulator action reported `Unable to connect to adb daemon on port: 5037`, repeatedly polled `adb shell getprop sys.boot_completed`, then timed out after 20 minutes. Integration test script did not reach Flutter test output.
- Physical Pixel 7 Pro full E2E passed after the dependency upgrade (140 passed, 5 skipped); this does not replace generated-consumer emulator coverage.
- CI run `42468614356`, attempt 1 and rerun attempt 2: `analyze-test` and `quality-gate` passed, generated-consumer analyze/tests and NDK setup passed, but `Build debug APK` failed both times before emulator setup. Gradle wrapper received HTTP 504 downloading `gradle-8.14-all.zip` from GitHub Releases; emulator step and its diagnostics were skipped.
- Local read-only HEAD request to the same Gradle distribution URL timed out after 30 seconds without response; this does not establish endpoint status during either CI attempt.
- Workflow diagnostics were moved into the emulator script via an `EXIT` trap and committed/pushed as `b259f2b4`; not yet exercised because both CI attempts failed earlier at APK build.

## Investigation checklist

- [x] Compare successful and timed-out run timelines: SDK install and APK build passed in both; emulator step took 2m31s on success and hit the 20m boundary on failed attempts.
- [x] Compare runner image/tool versions and emulator logs: versions matched, regions differed (`westcentralus` vs `southcentralus`); failed attempt stalled before test output while polling boot readiness. Exact ADB/emulator cause remains unproven.
- [x] Check generated-consumer setup: analysis/tests and APK build passed before emulator setup, so current evidence does not implicate generated-consumer configuration.
- [x] One further rerun was performed; it failed at the same emulator integration step. Do not retry again without a distinct diagnostic reason.
- [x] No workflow change justified by current evidence. Do not increase timeout; revisit only with logs that identify a bounded provisioning/ADB fix.
- [ ] If another independently scheduled run occurs, compare its emulator readiness and action logs against successful job `128633219027` and failed jobs `128655469951` / `128664806552` before proposing a change.

## Proposed diagnostic-only instrumentation (approval required before workflow edit)

Keep emulator version/API/timeout unchanged. Add one post-emulator step guarded by `if: always()` to capture bounded diagnostics even when the emulator step fails: `adb devices -l`, selected boot properties (`sys.boot_completed`, `init.svc.bootanim`), emulator/adb process status, and recent emulator logcat. Guard commands so missing device/log files do not mask the original failure; cap log output to avoid noisy CI logs. Do not add retries or alter SDK/AVD setup. This can distinguish an ADB server/device disconnect from a live emulator stuck during boot; it cannot prove a GitHub-hosted runner host fault by itself. Wait for a distinct CI run before deciding whether this instrumentation is needed; obtain explicit approval before editing `.github/workflows/ci.yml`.

## Next action

Wait for next independently scheduled `consumer-smoke` run. Keep workflow unchanged until that run provides a distinct diagnostic reason; then compare its boot/ADB state with the successful and failed job evidence above.

## Investigation conclusion

The failure is localized with high confidence to emulator readiness/provisioning before Flutter integration tests start. Generated-consumer analysis/tests/APK build pass. Runner image versions match between success and failure, but Azure regions differ; available evidence does not establish whether the underlying cause is runner infrastructure, AVD cold boot, or ADB. Leave `.github/workflows/ci.yml` unchanged and keep this item open for a distinct future run with more diagnostic logs.

Reference: successful job `128633219027`; failed jobs `128655469951` and `128664806552` in run `42456145100`.

- [x] Add bounded, read-only post-emulator diagnostics after approval; leave emulator configuration and timeouts unchanged.

## Acceptance criteria

- [ ] Classify failure as one of: runner/emulator infrastructure, generated-consumer build/configuration, or integration-test code, with exact log evidence.
- [ ] If a distinct rerun passes: record transient cold-boot/ADB instability and leave workflow unchanged.
- [ ] If it fails consistently at the same stage: document reproducible cause and a minimal proposed workflow fix; obtain approval before editing CI.
- [ ] Do not tag or publish a release as a workaround for a red required CI job.

## Constraints

- Work only on `main`; no branches or worktrees.
- Keep Flutter 3.41.9 pinned.
- Do not edit workflow, change timeout, commit, push, tag, or publish without separate approval.
