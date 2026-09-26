# Device QA Matrix

## Latest physical smoke

| Date | Device | OS source | Build | Result |
| --- | --- | --- | --- | --- |
| 2026-09-26 | TECNO KJ7 (`115333744A005844`) | Android via ADB | `example` release APK | PASS — install + launch smoke, no `FATAL EXCEPTION` / `AndroidRuntime` crash in scanned logcat |

## TECNO KJ7 proof commands

```bash
adb -s 115333744A005844 shell getprop ro.product.brand
adb -s 115333744A005844 shell getprop ro.product.model
cd example
flutter build apk --release
adb -s 115333744A005844 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s 115333744A005844 logcat -c
adb -s 115333744A005844 shell monkey -p com.galaxyjoy.roycasualkit 1
sleep 6
adb -s 115333744A005844 shell pidof com.galaxyjoy.roycasualkit
adb -s 115333744A005844 logcat -d -t 200 | grep -Ei "FATAL EXCEPTION|AndroidRuntime"
```

Expected:

- brand: `TECNO`
- model: `TECNO KJ7`
- APK builds successfully
- install returns `Success`
- launch returns a process id
- final crash grep returns no fatal crash

## Manual Game Demo smoke

1. Open app.
2. Open **Game Demo**.
3. Tap circle 10 times.
4. Verify `tap: 10/10`, `gems: 20`, star icon, and confetti.
5. Background and resume app.
6. Verify pause panel appears while backgrounded and disappears after resume.

## Automated proof

```bash
cd example
flutter test integration_test/d4_perf_memory_test.dart
```
