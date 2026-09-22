---
id: BUG-43
title: "ConnectivityCoordinator._runProbe thiếu catch — probe ném exception làm crash/kẹt trạng thái mạng vĩnh viễn"
type: bug
priority: P0
effort: S
source: "agy (độc lập), verify lại qua Read lib/core/connectivity_coordinator.dart:188-215"
---

## Vị trí
`lib/core/connectivity_coordinator.dart` — `_runProbe()`, gọi từ `_periodicProbe()` qua `unawaited(_runProbe())`.

## Hiện trạng
```dart
Future<void> _runProbe() async {
  if (_probeInFlight) return;
  _probeInFlight = true;
  try {
    final ok = await probe();
    ...
  } finally {
    _probeInFlight = false;
  }
}
```
Chỉ có `try/finally`, không có `catch`. `probe` do consumer app truyền vào (HTTP HEAD/socket check thật) — khi mất mạng/DNS lỗi, các implementation thật gần như luôn ném `SocketException`/`TimeoutException`.

## Vì sao cần / Hậu quả
Exception thoát ra khỏi `_runProbe()`, và vì hàm được gọi qua `unawaited(...)`, nó trở thành 1 unhandled async error (crash app hoặc kích hoạt `FlutterError.onError`/zone error handler tùy cấu hình). Ngoài crash, do exception thoát trước khi `_setState`/`_consecutiveFailures++` chạy, coordinator KẸT ở trạng thái `checking`/`online` cũ dù thiết bị đã mất mạng hoàn toàn — mọi logic phụ thuộc `ConnectivityState` (ví dụ auto-drain `OfflineOutboxService`) sai theo.

## Đề xuất
Bọc `await probe()` bằng `try { ... } catch (e) { ok = false; } finally { ... }` — coi mọi exception từ probe như "không có mạng", tăng `_consecutiveFailures`, cập nhật state đúng như nhánh `ok == false` hiện có.

## Acceptance criteria
- [ ] `probe` ném exception (`SocketException`/`TimeoutException`/exception bất kỳ) không làm crash app, không thoát ra ngoài `_runProbe()`.
- [ ] Sau khi `probe` ném exception đủ số lần (`failuresToGoOffline`), state chuyển đúng sang `offline`, không kẹt ở `checking`/`online`.
- [ ] `_probeInFlight` vẫn được reset về `false` đúng (không đổi hành vi `finally`).
- [ ] Test: mock `probe` ném các loại exception khác nhau, verify state transition đúng, verify không có unhandled exception thoát ra `Zone`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-43-connectivity-coordinator-missing-catch-in-probe.md` này trước khi làm. Đọc toàn bộ `lib/core/connectivity_coordinator.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria (bao gồm test verify không có unhandled exception qua `runZonedGuarded` hoặc tương đương).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix async-safety thuần, hành vi mạng thật không thể tái hiện tin cậy trên 1 device cụ thể).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp `_runProbe()`, xác nhận chính xác thiếu `catch`, chỉ có `try/finally`. Không trùng task nào trong `doc/task/done/`.
