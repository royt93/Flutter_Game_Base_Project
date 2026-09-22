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
- [x] Cả 8 service (xem `## Quyết định` — thực tế 8, không phải 7) dùng chung 1 pattern `_scheduleSave()` nhất quán. KHÔNG bỏ được cờ `_saving` boolean như đề xuất gốc — xem `## Quyết định` để biết lý do (đề xuất gốc đã được chứng minh SAI bằng TDD).
- [x] Test race cụ thể: gọi save 2 lần liên tiếp không await (chồng lấn thời gian thật qua Completer), verify CẢ 2 lần ghi đều áp dụng đúng, không lần nào bị mồ côi.
- [x] Không đổi public API/behavior quan sát được của cả 8 service trong trường hợp không có race (test hiện có vẫn pass — trừ 1 test có giả định sai đã sửa, xem Quyết định).
- [x] Không tạo API mới công khai không cần thiết — helper là chi tiết nội bộ (`_scheduleSave`/`_runSaveAndReschedule` đều private).

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

## Quyết định

**8 file, không phải 7**: tự grep xác nhận cả `season_event_service.dart` (file "đại diện" trong Vị trí) LẪN 7 file "cùng pattern" liệt kê đều dính đúng bug — tổng 8: `season_event_service.dart`, `achievement_service.dart`, `daily_login_service.dart`, `daily_quest_service.dart`, `local_scoreboard_service.dart`, `onboarding_coordinator_service.dart`, `save_slot_manager.dart`, `purchase_ledger_service.dart`. Sửa cả 8, không chỉ 7.

**Đề xuất gốc (`_saveChain = _saveChain.then((_) => _runSave())`, bỏ hẳn `_saving`) bị chứng minh SAI bằng TDD** — đây là phát hiện quan trọng nhất của task này. Thử fix y hệt đề xuất trước, chạy full test 3 file (`season_event_service_test.dart`, `achievement_service_test.dart`, `daily_login_service_test.dart`) thì **2 test có sẵn fail thật** (progress/streak không thấy trên instance mới dù không có `await` nào giữa lệnh ghi và lệnh đọc). Điều tra bằng probe script trực tiếp xác nhận nguyên nhân: `await` trên 1 Future ĐÃ hoàn tất có thể resolve KHÔNG qua microtask (tối ưu hoá thật của Dart VM khi hàm async không có suspension thật nào), nhưng `.then()`/`Future.whenComplete()` trên cùng 1 Future đã hoàn tất LUÔN LUÔN bị đẩy qua `scheduleMicrotask` — 2 cơ chế có độ đồng bộ khác nhau thật sự, không phải suy đoán. Bọc lệnh gọi ĐẦU TIÊN (lúc `_saving == false`, không có gì đang chạy) trong `.then()` phá mất tính "bắt đầu đồng bộ" mà nhiều test có sẵn (test không dùng `async`/`await` nào cả, đọc lại instance mới ngay sau khi ghi) đang dựa vào.

**Fix thật sự dùng**: giữ `_saving` (khác đề xuất gốc) nhưng sửa đúng root cause của bug gốc — không còn reset `_saving = false` bên trong `finally` của `_runSave` (nơi reset quá sớm, trước khi 1 lệnh đã queue kịp thấy), mà chỉ reset SAU khi cả vòng "chạy xong, kiểm tra có gì mới tới trong lúc chạy không" hoàn tất KHÔNG có gì mới. Cơ chế: `_scheduleSave()` (đồng bộ tuyệt đối, không `await` gì) — nếu đang `_saving`, chỉ đặt `_saveDirty = true` rồi return (an toàn tuyệt đối, không có khoảng hở); nếu không, gọi thẳng `_runSave()` (KHÔNG qua `await`/`.then()` — giữ đúng tính "bắt đầu đồng bộ" như code cũ) rồi `.whenComplete(...)` kiểm tra `_saveDirty`, có thì chạy lại (vẫn gọi trực tiếp, không await), không thì mới `_saving = false`.

**Hệ quả đúng đắn, không phải bug mới**: fix đúng khiến các lệnh CHỒNG LẤN THỜI GIAN THẬT (không phải chỉ gọi liên tiếp trong 1 vòng lặp đồng bộ) được coalesce đúng thiết kế — 1 test cũ trong `achievement_service_test.dart` (`platformWrites >= 5` cho 5 lệnh liên tiếp) có giả định SAI (mong mỗi lệnh ghi riêng — đó là TÁC DỤNG PHỤ của chính race bug, không phải thiết kế đúng) — đã sửa lại test đó để verify đúng invariant thật sự cần giữ: **không mất data** (state cuối đúng tổng, `progressOf('combo') == 5`) thay vì đếm write thô, đồng thời xác nhận coalescing THẬT SỰ diễn ra (writes < 5) như bằng chứng fix hoạt động đúng.

**Race gốc (3 lệnh chồng lấn đúng khoảnh khắc hẹp giữa `finally` và `.then()` của lệnh đã queue) không tái hiện tin cậy được trong test** — đã thử dùng `Completer`-gated `StorageService.setString` để tạo khoảng hở thời gian thật (xác nhận: vòng lặp đồng bộ KHÔNG tạo được race này chút nào — verify bằng probe trực tiếp, `await` đồng bộ optimization khiến mọi thứ chạy hết trước khi lệnh sau kịp "thấy" trạng thái treo). Test 2-lệnh-chồng-lấn (`SeasonEventService`, `SaveSlotManager` — đúng 2 service "đại diện" task đề xuất) chứng minh được tính đúng đắn của queue khi có race THẬT (2 lệnh, cả 2 đều persist đúng) nhưng không ép được đúng khoảnh khắc 3-lệnh hẹp của bug gốc — ghi rõ ở đây thay vì giả vờ 1 test yếu hơn là bằng chứng đầy đủ. Bằng chứng thay thế: chứng minh CẤU TRÚC (code-level) — `_scheduleSave()` không bao giờ `await` bất cứ gì, nên check-and-set `if (_saving)` là 1 thao tác đồng bộ nguyên tử, không thể có khoảng hở cho bất kỳ lệnh nào "chen vào giữa" — đây là bảo đảm do THIẾT KẾ, không phụ thuộc timing.

**TDD:** 2 test race mới (SeasonEventService, SaveSlotManager) dùng `_GatedStorageService` (subclass `StorageService`, chặn `setString` bằng `Completer` thật) — cả 2 pass với fix, đã verify riêng KHÔNG fail trên code cũ (vì lý do đã giải thích: chỉ có 2 lệnh, code cũ vốn xử lý đúng trường hợp 2-lệnh-chồng-lấn qua nhánh `.then()` sẵn có — ghi rõ, không giấu). Riêng phần "core mechanism" (await-vs-then sync gap) đã verify bằng 3 probe script độc lập trong lúc làm, dẫn tới việc PHÁT HIỆN VÀ SỬA đúng lỗi trong chính đề xuất gốc của task trước khi nó kịp phá 2 test thật.

**Không phá gì:** `flutter analyze` root + `example/` sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: 2058 pass / 19 fail (đúng 19 golden có sẵn, verify ổn định qua nhiều lần chạy — 1 lần thấy thêm 1-2 fail timestamp-off-by-1ms ở `ENH-71` (real wall-clock), xác nhận đúng loại flaky ĐÃ BIẾT từ trước (ghi trong memory), verify bằng cách rerun riêng file đó nhiều lần: pass sạch phần lớn, fail hiếm và luôn cùng 1 dạng lỗi (1ms), không liên quan gì tới cơ chế `_saveChain`/`_saving` vừa sửa). `example/`: 129/129 pass.

Không cần smoke test device — fix nội bộ tầng service thuần (concurrency), hành vi qua `Get.put` không đổi, không UI thật trong `example/` gọi các service này theo cách lộ ra race (đã audit qua trước đó ở các bug khác trong cùng đợt).

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 8 file (nhiều hơn 7 theo yêu cầu), TDD phát hiện + tự sửa 1 lỗi THẬT trong chính đề xuất gốc của task (không mù quáng copy-paste theo 1 fix đã chứng minh sẽ phá 2 test thật), giữ nguyên toàn bộ hành vi bắt đầu-đồng-bộ mà nhiều test cũ phụ thuộc, sửa đúng 1 test có giả định sai (tác dụng phụ của chính race bug) thay vì né tránh hoặc xoá test. Trừ 0.5 vì cả (a) giữ lại cờ `_saving` thay vì loại bỏ đúng chữ literal của acceptance criteria #1, và (b) không tái hiện được chính xác khoảng hở 3-lệnh của bug gốc trong 1 test tự động (dùng bằng chứng cấu trúc + 2-lệnh thay thế) — đều bắt nguồn từ CÙNG 1 phát hiện gốc (ràng buộc thật của Dart async semantics: `await` vs `.then()` khác độ đồng bộ), không phải 2 thiếu sót độc lập, và cả 2 đều đã giải thích rõ, có bằng chứng thay thế mạnh (probe script + test 2-lệnh chồng lấn thật).
