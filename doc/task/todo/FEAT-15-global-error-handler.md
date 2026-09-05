---
id: FEAT-15
title: Global error handler wiring (runZonedGuarded + FlutterError.onError)
type: feature
priority: P1
effort: S
verified: true
source: Claude, verify lại code thật (grep example/lib/main.dart)
---

## Vị trí
`example/lib/main.dart` — `runApp(RoyBaseGameApp(...))` được gọi trực tiếp,
không bọc `runZonedGuarded`, không có `FlutterError.onError`/
`PlatformDispatcher.instance.onError` custom.

## Vấn đề
Lỗi throw ngoài build method (async callback, timer, stream listener...) hiện
không được bắt ở đâu cả — rơi thẳng vào default Flutter handler. Kể cả khi
FEAT-04 (`CrashReporter` interface) được implement, sẽ không có nơi nào gọi
`CrashReporter.maybe?.recordError(...)` cho các lỗi này vì không ai catch
chúng trước.

## Đề xuất fix
Bọc `main()` bằng `runZonedGuarded((){ runApp(...); }, (error, stack) {
CrashReporter.maybe?.recordError(error, stack); })`, đồng thời override
`FlutterError.onError` để forward lỗi framework (build/layout/paint) vào cùng
1 chỗ.

## Acceptance criteria
- [ ] Throw thử 1 lỗi async trong `main.dart` (debug) → bị bắt bởi handler mới, không crash im lặng.
- [ ] Khi FEAT-04 hoàn thành, handler này gọi đúng `CrashReporter.maybe`.

## Phụ thuộc
Nên làm cùng lúc hoặc ngay sau FEAT-04.
