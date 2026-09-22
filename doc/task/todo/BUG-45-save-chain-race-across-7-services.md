---
id: BUG-45
title: "Pattern _saving/_saveChain dùng ở 7 service bị race: finally đặt _saving=false đồng bộ trước khi .then microtask kịp chạy"
type: bug
priority: P1
effort: M
source: "agy (độc lập), verify lại qua Read lib/core/season_event_service.dart:154 (đại diện, cùng pattern lặp ở 6 file khác)"
---

## Vị trí
`lib/core/season_event_service.dart:154` (đại diện), và cùng pattern ở `lib/core/achievement_service.dart`, `lib/core/daily_login_service.dart`, `lib/core/daily_quest_service.dart`, `lib/core/local_scoreboard_service.dart`, `lib/core/onboarding_coordinator_service.dart`, `lib/core/save_slot_manager.dart`, `lib/core/purchase_ledger_service.dart` — mọi nơi dùng cấu trúc:
```dart
_saveChain = _saving ? _saveChain.then((_) => _runSave()) : _runSave();
```
với `_runSave()` có `finally { _saving = false; }`.

## Hiện trạng
Khi 1 `_runSave()` trước đó kết thúc, khối `finally` đặt `_saving = false` ĐỒNG BỘ ngay lập tức. Nhưng `.then()` callback nối tiếp trên `_saveChain` (nếu có save khác đang xếp hàng) chỉ chạy ở 1 microtask SAU đó. Nếu có 1 lệnh save MỚI đến đúng khoảng hở giữa `finally` chạy và microtask `.then` kịp thực thi, `_saving` lúc đó đọc thấy `false` → code tạo `_saveChain = _runSave()` MỚI, độc lập, thay vì nối vào chuỗi cũ — `_saveChain` cũ bị mồ côi, 2 lần save chạy song song, ghi đè nhau trên disk theo thứ tự I/O không xác định (không phải thứ tự gọi).

## Vì sao cần / Hậu quả
Ảnh hưởng tới 7 service dùng chung pattern — bất kỳ pattern "double action nhanh liên tiếp" nào trên các service này (double-tap claim quest, 2 request save slot gần nhau, submit 2 điểm liên tiếp lên scoreboard...) đều có cơ hội (dù hẹp) ghi state cũ đè lên state mới, làm rollback tiến trình người chơi.

## Đề xuất
Bỏ cờ boolean `_saving`, dùng queue tuần tự chuẩn dựa hoàn toàn vào chuỗi Future, không dựa vào cờ đồng bộ:
```dart
Future<void> _scheduleSave() {
  final result = _saveChain.then((_) => _runSave());
  _saveChain = result.catchError((_) {});
  return result;
}
```
gọi `_scheduleSave()` tại mọi call site thay vì tự viết lại logic `_saving ? ... : ...` — đồng thời tách thành 1 method dùng chung (khớp với ENH-X1 nội bộ đã ghi nhận `SeasonEventService`/`SaveSlotManager` thiếu helper chung này).

## Acceptance criteria
- [ ] Cả 7 service dùng chung 1 helper `_scheduleSave()` (hoặc mixin/hàm tiện ích dùng chung), không còn cờ `_saving` boolean.
- [ ] Test race cụ thể: gọi save 2 lần liên tiếp không await, verify CẢ 2 lần ghi đều áp dụng đúng thứ tự gọi (lần sau không bị lần trước đè ngược lại do race window).
- [ ] Không đổi public API/behavior quan sát được của cả 7 service trong trường hợp không có race (test hiện có của cả 7 file vẫn pass).
- [ ] Không tạo API mới công khai không cần thiết — helper là chi tiết nội bộ.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-45-save-chain-race-across-7-services.md` này trước khi làm. Đọc toàn bộ cả 7 file liệt kê ở "Vị trí" — xác nhận đúng cấu trúc `_saving`/`_saveChain` giống hệt nhau ở tất cả — trước khi sửa. Implement bằng TDD, viết 1 test race trước cho ÍT NHẤT 2 service đại diện (ví dụ `SeasonEventService` và `SaveSlotManager`) rồi áp dụng fix đồng loạt cho cả 7.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, cho từng service trong 7 service.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (race window cực hẹp, không tái hiện tin cậy trên device thật; unit test với microtask control là bằng chứng đủ mạnh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp `season_event_service.dart:154` xác nhận đúng cấu trúc `_saving ? _saveChain.then(...) : _runSave()`; agy liệt kê 6 file khác dùng cùng pattern (chưa tự đọc lại từng file trong số đó do khối lượng, nhưng đây là pattern đã biết lặp lại nhất quán trong repo qua nhiều task done trước — BUG-17/BUG-18 cũ cũng nói về đúng family này). Người thực hiện task nên tự xác nhận lại từng file trước khi sửa (đã ghi rõ trong Prompt). Không trùng task nào trong `doc/task/done/`.
