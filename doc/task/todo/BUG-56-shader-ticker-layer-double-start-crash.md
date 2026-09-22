---
id: BUG-56
title: "ShaderTickerLayer gọi Ticker.start() khi ticker đã đang chạy → FlutterError 'A ticker was started twice'"
type: bug
priority: P0
effort: XS
source: "agy (độc lập), verify lại qua Read lib/presentation/widgets/shader_ticker_layer.dart:55-84"
---

## Vị trí
`lib/presentation/widgets/shader_ticker_layer.dart` — listener `ever<PerformanceTier>(...)`.

## Hiện trạng
```dart
_tierWorker = ever<PerformanceTier>(tierService.tier, (tier) {
  if (tier == PerformanceTier.low) {
    _ticker?.stop();
  } else if (_ticker == null) {
    _ticker = createTicker(_onTick)..start();
    _load();
  } else {
    _ticker!.start();
  }
});
```
Nhánh `else` cuối cùng gọi `_ticker!.start()` MỖI KHI tier đổi sang giá trị không phải `low` VÀ `_ticker` đã tồn tại — kể cả khi ticker đó ĐANG CHẠY (ví dụ tier đổi liên tiếp `medium` → `high`, không đi qua `low` ở giữa).

## Vì sao cần / Hậu quả
Gọi `Ticker.start()` khi ticker đang active ném `FlutterError: A ticker was started twice. / An active ticker cannot be started again.` — crash app ngay khi `PerformanceTierService` phát ra 2 lần liên tiếp cùng hướng "không phải low" (hoàn toàn có thể xảy ra tự nhiên khi FPS dao động quanh ngưỡng hysteresis).

## Đề xuất
Thêm guard `isTicking`:
```dart
} else if (!_ticker!.isTicking) {
  _ticker!.start();
}
```

## Acceptance criteria
- [ ] Tier đổi liên tiếp 2 lần đều không phải `low` (ví dụ `medium` → `high`) trong khi ticker đang chạy — không throw, ticker tiếp tục chạy bình thường.
- [ ] Tier đổi từ `low` → không-`low` (ticker đang dừng) vẫn start lại đúng như cũ.
- [ ] Test hiện có của `shader_ticker_layer_test.dart`/`aurora_bg_layer_test.dart`/`neon_aura_layer_test.dart` (nếu có) vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-56-shader-ticker-layer-double-start-crash.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/shader_ticker_layer.dart` và test hiện có (`AuroraBgLayer`/`NeonAuraLayer` đều dùng mixin này) trước khi sửa. Implement bằng TDD — viết test tái hiện đúng chuỗi tier-change gây crash trước khi sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria (cả `AuroraBgLayer` và `NeonAuraLayer` nếu chúng có test riêng).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (mở màn hình có `NeonBg`/`AuroraBgLayer` trong thời gian dài để tier dao động tự nhiên) nếu tiện, không bắt buộc vì unit test đã tái hiện đúng chuỗi sự kiện gây crash.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, xác nhận chính xác nhánh `else { _ticker!.start(); }` không có guard `isTicking`, đúng với hành vi crash đã biết của Flutter `Ticker`. Không trùng task nào trong `doc/task/done/`.
