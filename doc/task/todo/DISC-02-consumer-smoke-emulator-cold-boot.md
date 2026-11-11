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
- CI run `42475936590`, job `128717208224`, on commit `b259f2b4` ran in `centralus` / Ubuntu 26.04.1. Generated-consumer checks and APK build passed; emulator boot setup completed in about 42 seconds after transient `adb: device offline` recovered. The job then failed before Flutter tests with `/usr/bin/sh: 1: Syntax error: Unterminated quoted string`, from the multiline trap on that older commit. This is a shell-quoting failure, not another emulator timeout; the fix is in `1a60b126`. It does not explain earlier 20-minute stalls.
- Separate from emulator investigation: run `42468614356`, attempts 1 and 2, failed at APK build with HTTP 504 downloading Gradle 8.14 from GitHub Releases; emulator setup was skipped. A local HEAD request to that URL timed out after 30 seconds, which does not establish endpoint status during CI.
- CI run `42484320589` on commit `1a60b126`, runner region `centralus` / Ubuntu 26.04.1: all `analyze-test` and `quality-gate` steps passed; generated-consumer analyze/tests, APK build and emulator setup passed. Emulator reported `sys.boot_completed=1` at 13:26:01 UTC, about 45 seconds after launch; transient `adb: device offline` messages occurred earlier and recovered. `flutter test integration_test/app_boot_test.dart` then built the app and installed the APK by 13:26:50 UTC, but emitted no test-runner output before the emulator step hit its 20-minute timeout at 13:44:25 UTC. The `EXIT` trap diagnostics did not appear because the outer GitHub Actions step timeout killed the action. The stall is after emulator boot and APK install, before observable integration-test progress; exact cause (test launch/handshake, app startup, or device communication) remains unknown.
- CI uses generated test source from `tool/create_consumer_app.dart` (`integrationBootTestTemplate`), not `example/integration_test/app_boot_test.dart`.
- CI run `42489295855` on commit `5cc456e4` (job `128757931523`, region `eastus2`) added generated-test checkpoints. Emulator booted at 14:27:35 UTC, APK built and installed at 14:28:23 UTC, then `flutter test` emitted nothing until the 20-minute step timeout at 14:46:03 UTC; no `[consumer-smoke]` checkpoint appeared. Because stdout forwarding depends on the test starting and the VM Service handshake completing, this places the stall at or before test start, not in a specific test step.
- CI run `42494121926` on commit `28d1e967` (job `128772586593`) added a 60-second host watcher and `flutter test --verbose`. All three jobs passed. Emulator booted at 15:25:43 UTC; Flutter connected to VM Service and the `ext.flutter.integrationTest` isolate, and every checkpoint from `test-start` to `test-teardown-complete` printed; the test finished about 10 seconds after connecting. The watcher and cleanup ran normally.
- This pass verifies the new instrumentation and shows the generated test and handshake succeed when the app launches normally. It does not explain the earlier 20-minute stalls, and one pass does not rule out the intermittent failure.
- CI run `42820500983` on commit `30307dae` (job `consumer-smoke`, region `eastus3`) timed out with the watcher and `--verbose` active. Emulator booted in ~56 s (transient `adb: device offline` x5 at start, recovered); APK built and installed at 13:08:45–13:08:54 UTC. Flutter then launched `com.example.ci_smoke`, forwarded the VM Service, started DDS, connected, found the `ext.flutter.integrationTest` isolate and logged `test 0: connected to test device, now awaiting test result` / `Waiting for test harness or tests to finish` at 13:09:01 UTC. No `[consumer-smoke]` checkpoint (not even `test-start`) was ever printed, and no further Flutter output followed until the step timeout at 13:26:11 UTC.
- The 60 s watcher snapshots through the stall showed `emulator-5554` stayed `device`, `sys.boot_completed=1`, and the `com.example.ci_smoke` process (pid 4565) stayed alive (`S`, RSS ~350 MB) for the full ~17 minutes. The watcher's logcat filter showed no `Fatal exception` / `AndroidRuntime`, so this is not an ADB loss or app crash.
- This changes the earlier classification (run `42489295855`, "stall at or before test start"): the harness handshake succeeds, then the generated test never reaches its first line (no `test-start`) or its output is not forwarded. Cause is still unknown; candidates are the test isolate not executing `main`/`testWidgets` or checkpoint `debugPrint` output not reaching the host. No timeout/AVD change is justified.
- CI run `42826929020` on commit `9c4f9c92` (region `centralus`) timed out again, now with the app-side `flutter` logcat watcher. Same pattern: boot ~46 s, install 1.5 s, `test 0: connected to test device, now awaiting test result`, then silence until the 20-minute step timeout at 14:08:53 UTC. The watcher's `adb logcat -s flutter:V` shows only three app lines the whole time: `Using Impeller rendering backend (OpenGLES)` at 13:51:23, `The Dart VM service listening on http://127.0.0.1:39379/...` at 13:51:23.4 and a second `Using Impeller rendering backend (OpenGLES)` at 13:51:35 (a second engine/surface, ~12 s after the first). No `[consumer-smoke]` checkpoint and no `I/flutter` output from the test or from `app.main()` appeared. App process 4824 stayed alive (`S`, RSS ~318 MB) and `emulator-5554` stayed `device` for the whole stall.
- The scheduled thread dump did not run: `kill -3 4824` returned `Operation not permitted` (the `adb shell` user cannot signal the app uid), so the dump needs `run-as` or `am dump-heap` / `debuggerd` alternatives. Note the app is a debuggable debug build, so `run-as com.example.ci_smoke` is a candidate.
- Two data points (`42820500983`, `42826929020`) now show the harness handshake completing and the app engine starting, but the test body producing no output; evidence still does not distinguish "test never starts" from "test starts and output is not forwarded". It also does not explain the earlier runs that stalled before the handshake.
- CI run `43019209563` on commit `38d7fcad` (region `westus2`) timed out a fourth time with the identical pattern: boot ~46 s, `test 0: connected to test device, now awaiting test result`, then only the engine lines in the `flutter` logcat (two `Using Impeller rendering backend` ~10 s apart and `Dart VM service is listening`), no `[consumer-smoke]` checkpoint, app process 4721 alive and `emulator-5554` `device` until the step timeout at 12:45:05 UTC. The `run-as ... kill -3` dump executed without error this time but returned no lines from the `DALVIK THREADS|"main"|"1.ui"|"1.raster"|flutter` filter, so it produced no usable stack: a debug Flutter app runs the Dart/engine threads natively and ART's SIGQUIT dump does not show them.
- Four hung runs (`42489295855`, `42820500983`, `42826929020`, `43019209563`) in regions `centralus`, `eastus3`, `westus2` rule out a single-region runner. All show a healthy app/ADB and a successful harness connection, followed by a test that produces no output. Candidate causes remain the test isolate not running the test body (e.g. blocked before `testWidgets`) or output not forwarded; the logcat/thread-dump approach cannot tell them apart.
- Current evidence establishes intermittent ADB offline during boot that recovered before setup completed; this is not by itself the cause of the observed post-install hang.

## Investigation checklist

- [x] Compare successful and timed-out run timelines: SDK install and APK build passed in both; emulator step took 2m31s on success and hit the 20m boundary on failed attempts.
- [x] Compare runner image/tool versions and emulator logs: versions matched, regions differed (`westcentralus` vs `southcentralus`); failed attempt stalled before test output while polling boot readiness. Exact ADB/emulator cause remains unproven.
- [x] Check generated-consumer setup: analysis/tests and APK build passed before emulator setup, so current evidence does not implicate generated-consumer configuration.
- [x] One further rerun was performed; it failed at the same emulator integration step. Do not retry again without a distinct diagnostic reason.
- [x] Keep emulator configuration and timeout unchanged; the later passing run does not identify a bounded fix for the earlier timeout.
- [x] Compare naturally scheduled run `42475936590` against the passing diagnostics run: it reproduces the already-fixed trap quoting error on older commit `b259f2b4`, not the cold-boot timeout.
- [ ] If another independently scheduled run occurs, compare its emulator readiness and action logs against successful job `128633219027` and failed jobs `128655469951` / `128664806552` before proposing a change.

## Diagnostic instrumentation

The emulator script runs bounded, read-only diagnostics on shell exit: `adb devices -l`, boot properties (`sys.boot_completed`, `init.svc.bootanim`), emulator/ADB process status, emulator log paths, and recent logcat. CI run `42479899176` verified the capture runs after a successful integration test and does not change its result. The capture is limited to the emulator script; it cannot observe a failure that occurs before that script starts.

## Next action

The stall recurred on runs `42820500983` and `42826929020` after the handshake (see evidence). The app-side `flutter` logcat shows only engine start-up lines; the `kill -3` thread dump failed with `Operation not permitted`. Next (needs approval, it edits CI): fix the dump with `run-as com.example.ci_smoke` (or `adb shell am dump-heap`/`debuggerd -b`), and in the same change dump the test isolate state through the VM Service (e.g. `flutter attach`-less `curl` to the forwarded DDS port is not available on the guest, so prefer a host-side `adb forward` + a small `dart` script calling `getVM`/`getIsolate`) so the next stall shows whether the isolate is running `main`, paused, or blocked. Also compare with passing job `128772586593` for the second `Using Impeller` line and the time of `test-start`. Do not change timeout or emulator configuration without log proof of the cause.

## Investigation conclusion

Past failures are localized with high confidence to emulator readiness/provisioning before Flutter integration tests start. Run `42479899176` proves the integration test and diagnostics work on a later successful attempt, with a transient ADB-offline state recovering during boot. Available evidence still does not establish why earlier runs timed out or distinguish runner infrastructure from AVD/ADB behavior; keep this item open and do not change emulator configuration or timeout without stronger evidence.

Reference: successful jobs `128633219027` and `128729361841`; failed jobs `128655469951` / `128664806552` in run `42456145100`; Gradle download failure run `42468614356`.

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
