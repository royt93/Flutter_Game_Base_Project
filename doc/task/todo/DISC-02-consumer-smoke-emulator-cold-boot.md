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
- Workflow diagnostics were moved into the emulator script via an `EXIT` trap and committed/pushed as `b259f2b4`.
- CI run `42475936590` on `b259f2b4`: generated-consumer checks, NDK install, and APK build passed. Emulator runner started API 34 AVD; its log showed initial `adb: device offline`, then `sys.boot_completed` polling succeeded and boot setup completed in about 41 seconds. The integration script then failed before Flutter tests with `/usr/bin/sh: 1: Syntax error: Unterminated quoted string`; this was caused by the newly added multiline `trap` body, so the diagnostics did not execute.
- The follow-up one-line `bash -c` trap passes shell syntax, preserves the Flutter test exit status in a stubbed local check, and was validated on CI run `42479899176` after commit `1a60b126`.
- CI run `42479899176` passed `consumer-smoke`, `analyze-test`, and `quality-gate`. Diagnostics ran after the integration test: `adb devices -l` showed `emulator-5554` as `device`, `sys.boot_completed` was `1`, and `init.svc.bootanim` was `stopped`. The log also showed transient `adb: device offline` polling during boot before the emulator became ready; the integration test then passed.
- This successful run verifies the diagnostic script and confirms one ADB-offline-during-boot event recovered. It does not establish the cause of prior 20-minute timeouts.
- Separate from emulator investigation: run `42468614356`, attempts 1 and 2, failed at APK build with HTTP 504 downloading Gradle 8.14 from GitHub Releases; emulator setup was skipped. A local HEAD request to that URL timed out after 30 seconds, which does not establish endpoint status during CI.
- Current evidence establishes intermittent ADB offline during boot that recovered before setup completed; it does not establish this as the cause of earlier 20-minute emulator timeouts.

## Investigation checklist

- [x] Compare successful and timed-out run timelines: SDK install and APK build passed in both; emulator step took 2m31s on success and hit the 20m boundary on failed attempts.
- [x] Compare runner image/tool versions and emulator logs: versions matched, regions differed (`westcentralus` vs `southcentralus`); failed attempt stalled before test output while polling boot readiness. Exact ADB/emulator cause remains unproven.
- [x] Check generated-consumer setup: analysis/tests and APK build passed before emulator setup, so current evidence does not implicate generated-consumer configuration.
- [x] One further rerun was performed; it failed at the same emulator integration step. Do not retry again without a distinct diagnostic reason.
- [x] Keep emulator configuration and timeout unchanged; the later passing run does not identify a bounded fix for the earlier timeout.
- [ ] If another independently scheduled run occurs, compare its emulator readiness and action logs against successful job `128633219027` and failed jobs `128655469951` / `128664806552` before proposing a change.

## Diagnostic instrumentation

The emulator script runs bounded, read-only diagnostics on shell exit: `adb devices -l`, boot properties (`sys.boot_completed`, `init.svc.bootanim`), emulator/ADB process status, emulator log paths, and recent logcat. CI run `42479899176` verified the capture runs after a successful integration test and does not change its result. The capture is limited to the emulator script; it cannot observe a failure that occurs before that script starts.

## Next action

Wait for the next independently scheduled `consumer-smoke` run. If emulator readiness times out again, compare its captured ADB/boot state with successful job `128729361841` and failed jobs `128655469951` / `128664806552` before proposing any configuration or timeout change.

## Investigation conclusion

Past failures are localized with high confidence to emulator readiness/provisioning before Flutter integration tests start. Run `42479899176` proves the integration test and diagnostics work on a later successful attempt, with a transient ADB-offline state recovering during boot. Available evidence still does not establish why earlier runs timed out or distinguish runner infrastructure from AVD/ADB behavior; keep this item open and do not change emulator configuration or timeout without stronger evidence.

Reference: successful jobs `128633219027` and `128729361841`; failed jobs `128655469951` and `128664806552` in run `42456145100`; Gradle download failure run `42468614356`.

- [x] Add bounded, read-only post-emulator diagnostics after approval; leave emulator configuration and timeouts unchanged.

## Acceptance criteria

- [ ] Classify failure as one of: runner/emulator infrastructure, generated-consumer build/configuration, or integration-test code, with exact log evidence.
- [x] Passing run `42479899176` recorded transient ADB-offline-during-boot recovery; emulator configuration and timeout remain unchanged.
- [ ] If it fails consistently at the same stage: document reproducible cause and a minimal proposed workflow fix; obtain approval before editing CI.
- [ ] Do not tag or publish a release as a workaround for a red required CI job.

## Constraints

- Work only on `main`; no branches or worktrees.
- Keep Flutter 3.41.9 pinned.
- Do not edit workflow, change timeout, commit, push, tag, or publish without separate approval.
