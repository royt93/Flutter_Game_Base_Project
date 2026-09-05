---
id: FEAT-04
title: Crash reporting hook trung lập
type: feature
priority: P1
effort: S
source: fork nội bộ + claude-CLI
---

## Vì sao cần
`dlog()` (`lib/core/debug_log.dart`) no-op hoàn toàn ở release build — nghĩa
là mọi lỗi runtime ở production hiện tại im lặng, không ai biết. Không có hook
nào để cắm Crashlytics/Sentry.

## Đề xuất phạm vi
1 interface tối giản theo đúng pattern `AudioManager.maybe`:
```dart
abstract class CrashReporter {
  void recordError(Object error, StackTrace stack, {String? reason});
}
```
Kèm `CrashReporter.maybe` accessor, mặc định null-safe no-op nếu app chưa
đăng ký implementation nào — không bắt buộc phụ thuộc Firebase/Sentry ở
package gốc.

## Acceptance criteria
- [ ] Interface tồn tại trong `lib/core/`, không kéo dependency crash SDK nào vào `pubspec.yaml`.
- [ ] `CrashReporter.maybe` trả `null` an toàn khi chưa đăng ký, giống `AudioManager.maybe`.
