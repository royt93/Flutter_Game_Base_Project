---
id: BUG-42
title: "requestCheckpoint() debounce: Completer cũ bị bỏ rơi vĩnh viễn khi có request mới chồng lên"
type: bug
priority: P1
effort: S
source: "agy + claude (độc lập xác nhận cùng bug), verify lại qua Read lib/core/checkpoint_coordinator.dart:90-110"
---

## Vị trí
`lib/core/checkpoint_coordinator.dart` — `requestCheckpoint({bool critical = false})`.

## Hiện trạng
```dart
_debounceTimer?.cancel();
final completer = Completer<SdkResult<int>>();
_debounceTimer = _createTimer(debounceWindow, () {
  completer.complete(flushNow());
});
return completer.future;
```
Mỗi lần gọi `requestCheckpoint()` (không `critical`) trong lúc 1 debounce trước đó đang chờ: `_debounceTimer?.cancel()` hủy timer CŨ, nhưng `Completer` của lần gọi TRƯỚC (đã được return cho caller trước đó) không hề được `complete()` — future đó treo vĩnh viễn.

## Vì sao cần / Hậu quả
Bất kỳ caller nào `await requestCheckpoint()` rồi bị 1 request checkpoint khác đến sau (debounce coalesce) sẽ `await` một `Future` KHÔNG BAO GIỜ hoàn thành — treo coroutine gọi nó vĩnh viễn (leak + tiềm ẩn deadlock nếu logic game chờ checkpoint xong mới làm bước tiếp theo).

## Đề xuất
Giữ 1 danh sách các `Completer` đang chờ (thay vì chỉ biến `completer` cục bộ mới nhất); khi timer thật sự chạy (`flushNow()` xong), `complete()` TẤT CẢ completer đang chờ trong batch đó với cùng 1 kết quả, thay vì chỉ completer mới nhất.

## Acceptance criteria
- [ ] Gọi `requestCheckpoint()` 2 lần liên tiếp trong debounce window — CẢ 2 future trả về đều `complete()` (cùng kết quả `flushNow()` duy nhất được chạy), không future nào bị treo.
- [ ] `critical: true` vẫn hoạt động như cũ (flush ngay, không qua debounce).
- [ ] Test verify bằng timeout ngắn: awaiting future của request bị coalesce phải hoàn thành trong thời gian hợp lý, không treo.
- [ ] Không đổi hành vi debounce hiện có khi chỉ có 1 request duy nhất.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-42-checkpoint-coordinator-completer-leak-on-debounce.md` này trước khi làm. Đọc toàn bộ `lib/core/checkpoint_coordinator.dart` và test hiện có trước khi sửa. Implement bằng TDD (viết test fail trước — verify future bị coalesce treo vĩnh viễn — rồi code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic thuần async, không UI).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — 2 nguồn độc lập (agy, claude) xác nhận cùng bug; tự Read trực tiếp code, cấu trúc `completer`/`_debounceTimer` khớp chính xác mô tả. Không trùng task nào trong `doc/task/done/`.
