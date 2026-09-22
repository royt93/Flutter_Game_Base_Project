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
- [x] Gọi `requestCheckpoint()` 2 lần liên tiếp trong debounce window — CẢ 2 future trả về đều `complete()` (cùng kết quả `flushNow()` duy nhất được chạy), không future nào bị treo.
- [x] `critical: true` vẫn hoạt động như cũ (flush ngay, không qua debounce).
- [x] Test verify bằng timeout ngắn: awaiting future của request bị coalesce phải hoàn thành trong thời gian hợp lý, không treo.
- [x] Không đổi hành vi debounce hiện có khi chỉ có 1 request duy nhất.

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

## Quyết định

Fix đúng như đề xuất — đổi 1 `completer` đơn thành `_pendingCompleters` (list), mỗi `requestCheckpoint()` không-critical thêm 1 completer vào list; khi debounce thật sự fire (hoặc bị `critical` preempt), gọi `_completePending(flushNow())` complete HẾT list cùng lúc bằng cùng 1 kết quả flush, rồi clear list.

**Mở rộng thêm 1 điểm cùng root cause, cùng file, không nằm trong acceptance criteria gốc nhưng cùng shape bug 1-đến-1**: nhánh `critical: true` cũng `_debounceTimer?.cancel()` y hệt logic coalesce — nếu có 1 request không-critical đang chờ debounce, rồi 1 request `critical: true` đến sau, code CŨ chỉ trả về kết quả cho request critical, còn completer của request không-critical trước đó bị bỏ rơi y hệt bug gốc. Sửa bằng cách gọi lại đúng `_completePending()` trong nhánh `critical` — tái dùng chung 1 helper, không thêm cơ chế mới. Test "critical hủy debounce đang chờ" đã có sẵn trong file được mở rộng để `await` luôn future của request không-critical (trước đây bị bỏ qua, không await).

**TDD:** viết 3 test mới trước — `git stash` riêng file lib, chạy lại — cả 3 test TIMEOUT THẬT (`TimeoutException after 0:00:01.000000`, không phải assertion fail thông thường) — bằng chứng mạnh nhất trong các task đã làm: chứng minh chính xác "future treo vĩnh viễn" đúng như mô tả, không phải suy đoán lý thuyết. Khôi phục fix: cả 15 test (12 cũ + 3 mới) pass, không đổi hành vi debounce/critical hiện có.

**Không phá gì:** `flutter analyze` root sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: 2051 pass / 19 fail (đúng 19 golden có sẵn, không tăng).

Không cần smoke test device — fix nội bộ tầng service thuần (debounce/Completer), hành vi qua `Get.put` không đổi, không có UI thật gọi `requestCheckpoint()` theo cách lộ ra bug này trong `example/`.

**Tự chấm điểm: 9.5/10.** Fix đúng root cause, mở rộng đúng 1 chỗ cùng shape bug trong cùng phương thức (không lan sang file khác, rủi ro thấp), TDD chứng minh bằng timeout thật — bằng chứng khó phản bác nhất từ đầu đợt fix P1 tới giờ.
