# Device QA Matrix

Records describe one build and one exercised flow. Install/launch smoke,
interactive integration, and performance measurements are separate evidence.
They do not certify every feature or the current release.

## Recorded evidence

| Date | Device / OS | Source and build | Type | Result / evidence |
| --- | --- | --- | --- | --- |
| 2026-11-28 14:45 +07 | Samsung Galaxy S24 Ultra `SM-S928B`, Android 17/API 37, physical, 1080x2340 | Source `b8e36080` plus uncommitted ENH-127 test; example debug, `E2E_TEST=true` | Manual frame + memory profile (3 runs) | `device_jank_memory_test.dart`; medians across runs: **Match-3** 591 frames, build p50/p90/p99 1.871/2.528/3.912ms, raster 4.825/6.588/10.011ms, total 7.333/9.871/13.551ms, >16.667ms 1 frame (0.17%). **Widget Showcase** 148 frames, build 20.577/52.703/363.625ms, raster 8.193/25.869/31.377ms, total 31.231/68.401/383.285ms, >16.667ms 128 frames (75.71%). High Showcase total reflects the `runAsync` 3× scroll up/down workload and must not be read as a general idle-frame rate. Memory: 3s `dumpsys meminfo` sampling of `com.galaxyjoy.roycasualkit` while the integration test process was alive; per-run PSS sample medians 584,173 / 538,032.5 / 542,936 KB; median-of-run-medians 542,936 KB; samples range 404,094–764,972 KB across transitions/scenes. App returned to launcher; device settings unchanged (font scale 1.08, auto-rotate on, rotation 0). Raw evidence: `doc/task/evidence/ENH-127-s24u-run-log.txt`. **No pass/fail budget set** (first measurement only); no CI gate or `performance_budget_policy.json` change. First invalid attempt (route Future waited forever; before/after package dump found no process) excluded. |
| 2026-11-24 19:40 +07 | TECNO KJ7, Android 14 (physical, NOT the S24U standard device) | Source `5e2b0805` plus the new uncommitted `interruption_test.dart`; example debug, `E2E_TEST=true` | Interactive integration | `interruption_test.dart`: Match-3 session driven through the real binding. 5 background/foreground cycles, `inactive>hidden>paused`, and a player pause across a round trip all ended in the expected phase; pause took ~52ms, resume 0-1ms, zero hook failures. Log: `doc/task/evidence/ENH-124-interruption-device.log`. **Does not prove:** process kill, a real phone call, or real device rotation (the test's rotation step only asserts no exception; no orientation check on screen). Not run on S24U. |
| 2026-11-23 | Google Pixel 7 Pro, Android 17 (physical, not S24U) | Source `d33bef36`; example debug, `E2E_TEST=true` | Interactive integration | `app_boot_test.dart` test `Match-3 Lite opens and runs one valid swap on device` passed (1/1). Exercises `Match3Lite` screen with the package `Match3Engine` (default `Match3Config.classic`): open, one valid swap. Does not cover boosters, 5-level progression, save/restore, performance or other devices. [log](../../doc/task/evidence/FEAT-212-pixel7pro-match3-lite-smoke.log) |
| 2026-11-21 | Samsung Galaxy S24 Ultra `SM-S928B`, Android 16 | Source later committed as `d6ae94f2`; example debug, `E2E_TEST=true` | Interactive integration | `analytics_ack_recovery_test.dart` passed: simulated ACK-save failure retains Pending=1 / Uploaded=0; retry produces Pending=0 / Uploaded=1. [Saved run log](../../doc/task/evidence/BUG-139-s24u-analytics-ack-recovery.log). |
| 2026-11-21 16:12:30.507 UTC | Samsung Galaxy S24 Ultra `SM-S928B`, Android 16 | Source `d6ae94f2`; baseline commit `d3a9326c`; debug integration | Boot-test command wall time | `example_app_boot_wall_ms=32952 ms`, source `realDevice`, `recordedAtMs=1795277550507`. [Committed baseline](../../tool/performance_budget_baseline.json). No separate raw benchmark run log was retained. |
| 2026-09-26 | TECNO KJ7, Android 14, arm64-v8a, 1080×2436, ~7.5GB RAM | Historical example release APK, `61.6MB`; source commit not recorded | Install / launch smoke | Historical PASS: install succeeded, process pid confirmed, no `FATAL EXCEPTION` / `AndroidRuntime` found in scanned logcat. Raw log and APK hash were not retained here; not current-release proof. |

### Scope and limitations

- The ACK integration uses synthetic events, a local fake uploader, and isolated
  `StorageService(null)` RAM storage. It does not prove real backend delivery,
  real disk-failure handling, fsync durability, or exactly-once effects. The
  screenshot previously named `ack-retry` still shows the failure state, so it
  is not used as successful-retry proof; the saved integration log is the
  passing flow evidence.
- The boot metric times the full `flutter test` subprocess around
  `app boots to HomeScreen` in `app_boot_test.dart`, including build/install/test
  overhead. It is not isolated app startup latency, frame time, memory, or FPS.
  The tool does not establish a controlled cold-start environment.
- Performance freshness is evaluated by
  `tool/performance_budget_policy.json` against each metric's `recordedAtMs`.
  A previously passing result can expire; use the current check instead of
  treating this table as an indefinitely passing gate.
- Old records remain historical. Missing metadata is marked unknown, not
  reconstructed from an unrelated build or newer device run.

## Reproduce on a physical device

From the repository root, discover the current serial; stored serials below
identify past runs only. Check the foreground app and obtain permission before
interrupting unrelated device work.

```bash
adb devices -l
adb -s <device-id> shell getprop ro.product.model
adb -s <device-id> shell getprop ro.build.version.release
```

ACK failure/retry integration:

```bash
cd example
flutter test integration_test/analytics_ack_recovery_test.dart -d <device-id> --dart-define=E2E_TEST=true
```

The recorded S24U run used `R5CX613VZBR`. The test opens Home → **Analytics ACK
smoke** and exercises the demo controls. No external analytics or ad request is
part of this flow.

Performance freshness/budget check (read-only; from repository root):

```bash
dart run tool/performance_budget_check.dart check
```

Collect a new measurement only when authorized; `snapshot` writes the baseline
and refreshes host measurements too:

```bash
dart run tool/performance_budget_check.dart snapshot --device=<device-id> --deviceSource=realDevice
```

Do not refresh only the timestamp, relax the policy, or label an emulator run
`realDevice` to make a gate pass.

## Historical TECNO install / launch procedure

These commands describe the 2026-09-26 procedure, not a new execution. The old
serial was `115333744A005844`; discover the current serial before reuse. Release
signing requires private configuration. Inspect only log output relevant to
the run; no unrelated device data belongs in shared proof.

```bash
cd example
flutter build apk --release
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
adb -s <device-id> shell monkey -p com.galaxyjoy.roycasualkit 1
adb -s <device-id> shell pidof com.galaxyjoy.roycasualkit
adb -s <device-id> logcat -d -t 200 | grep -Ei "FATAL EXCEPTION|AndroidRuntime"
```

A pid plus no matching fatal error only establishes launch smoke for that
scanned window; it does not establish gameplay, pause/resume, or performance.

## Manual Classic Flame scenario (not a new recorded result)

1. Open Home → **Flame Demo** → **Classic Flame Demo** (English labels).
2. Tap the circle 10 times.
3. Verify `tap: 10/10`, `gems: 20`, star icon, and confetti.
4. Background and resume the app; verify lifecycle behavior using visible
   state and logs. Do not infer background-state visibility from a foreground
   screenshot.

```bash
cd example
flutter test integration_test/d4_perf_memory_test.dart -d <device-id> --dart-define=E2E_TEST=true
```

## Record format

Use this same metadata for a README summary and its detailed matrix entry:

- Date/time and timezone; device model, OS, physical/emulator classification.
- Source commit (or clearly described working-tree state); build mode, defines,
  package, and artifact hash when captured.
- Evidence type: install/launch, interactive integration, or named measurement.
- Exact command/selector and exercised route/actions.
- Observed result, log/screenshot path, and what the evidence does **not** prove.
- Missing metadata, historical/freshness status, and any failed attempts.

Retain logs under `doc/task/evidence/` rather than linking only to temporary
files. A new run adds a record; it does not silently rewrite old proof.
