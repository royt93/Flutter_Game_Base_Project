---
id: ENH-90
title: "Demo trong example/ cho rescheduleEnergyReminder/rescheduleStreakReminder (IDEA-62) và comboSyncHapticPattern (IDEA-67)"
type: enhancement
priority: P3
effort: S
source: "claude (fork audit, độc lập) — 2 fork độc lập cùng phát hiện gap này"
---

## Vị trí
`lib/core/utils/smart_reminder_scheduling.dart` (`rescheduleEnergyReminder`/`rescheduleStreakReminder`, IDEA-62), `lib/core/haptic_choreographer.dart` (`comboSyncHapticPattern`, IDEA-67) — cả 3 hàm chưa có nơi nào gọi trong `example/lib/`.

## Hiện trạng
`grep -rn "rescheduleEnergyReminder\|rescheduleStreakReminder\|comboSyncHapticPattern" example/lib/` → 0 kết quả. `example/lib/screens/widget_showcase_screen.dart` đã đăng ký/demo riêng lẻ `EnergyService`, `DailyLoginService`, `HapticChoreographer` — nhưng đúng 3 hàm điều phối/xây dựng mà IDEA-62 và IDEA-67 build ra để NỐI chúng lại thì chưa từng được gọi ở đâu trong app thật, chỉ tồn tại qua unit test mock. Cả 2 task tự trừ điểm (9.5/10) vì thiếu chính điều này trong mục `## Quyết định` của mình.

## Vì sao cần / Hậu quả
Đây là 2 trong số ít feature của cả đợt session vừa qua không có bất kỳ minh chứng chạy thật nào trong app — khác với hầu hết mọi tính năng khác (mỗi cái đều có ít nhất 1 nút demo trong `WidgetShowcaseScreen`/`CookbookScreen`). Người dùng kit đọc code sẽ không có nơi nào để THẤY 2 hàm reminder hoạt động cùng lúc với `EnergyService`/`DailyLoginService` thật, hay thấy `comboSyncHapticPattern` phối hợp với 1 chuỗi combo demo thật.

## Đề xuất
Thêm 2-3 nút nhỏ:
- Trong `WidgetShowcaseScreen`'s section Energy/DailyLogin hiện có: nút gọi `rescheduleEnergyReminder`/`rescheduleStreakReminder` thật (dùng `ReminderService`/`EnergyService`/`DailyLoginService` đã đăng ký sẵn), hiện text/toast kết quả (delay tính được hoặc "đã huỷ vì đầy/đã claim").
- Trong `cookbook_screen.dart` (theo đúng convention "1 tile, 1 nút, 1 toast" IDEA-66 đã dùng): 1 tile gọi `comboSyncHapticPattern` với vài bước combo giả lập, phát qua `HapticChoreographer` thật, hiện số pulse + tổng thời lượng.

## Acceptance criteria
- [x] Nút reschedule reminder gọi đúng hàm thật, kết quả hiển thị đúng theo trạng thái Energy/DailyLogin hiện tại (đủ/thiếu năng lượng, đã/chưa claim hôm nay).
- [x] Tile combo-sync haptic gọi đúng `comboSyncHapticPattern` + `HapticChoreographer.play()` thật, không throw.
- [x] Test widget verify cả 2-3 nhánh mới (không phải chỉ "không crash" — verify đúng nội dung kết quả hiển thị).
- [x] Không phá bất kỳ demo/tile nào có sẵn trong 2 màn hình bị sửa.

## Quyết định

**Implementation:**
- `example/lib/screens/cookbook_screen.dart`: thêm 1 tile mới gọi `comboSyncHapticPattern(steps: 5, stepInterval: 120ms)` rồi `_haptics.play(pattern)` (tái dùng `HapticChoreographer` đã có sẵn ở `initState`), hiện số pulse + chuỗi level qua toast.
- `example/lib/screens/widget_showcase_screen.dart`: thêm field `_reminder` (`ReminderService.maybe ?? Get.put(...)`), 2 method `_rescheduleEnergyReminder`/`_rescheduleStreakReminder` gọi đúng `rescheduleEnergyReminder`/`rescheduleStreakReminder` thật (dùng `_energy`/`_dailyLogin` đã đăng ký sẵn trong screen), cập nhật `setState` với text kết quả tiếng Việt. Thêm 1 block UI mới (2 nút + 2 dòng trạng thái) chèn giữa demo EnergyBar và WheelSpinner.
- 2 import mới cần thêm thủ công (`reminder_service.dart`, `utils/smart_reminder_scheduling.dart`) vì file này import theo từng file, không dùng barrel như `cookbook_screen.dart`.

**TDD:** `git stash push` 2 file lib → chạy 5 test mới → tất cả fail đúng lý do (cookbook: "No element" vì tile chưa tồn tại; widget_showcase: 4 test lỗi tìm nút "Reschedule energy/streak reminder" không thấy) → `git stash pop` → chạy lại pass.

**Lỗi phát hiện + sửa trong lúc TDD:**
1. `find.text('Reschedule energy reminder')` ban đầu match 2 widget (StrokeText render stroke+fill = 2 `Text`) → sửa sang `find.widgetWithText(CommonButton, '...').first`, đúng convention đã dùng ở hàng chục chỗ khác trong cùng file test.
2. Chèn block mới đẩy tổng chiều cao list dài hơn, làm demo `ComboHeatBackground` (section "Game Feel", test `IDEA-08`) rớt ra ngoài viewport ảo cố định 15000px trong `_pumpShowcase` → regression thật (verify bằng cách stash lại, chạy riêng `IDEA-08` trên code cũ: pass; trên code mới: fail "Heat: 0%" không tìm thấy). Sửa bằng cách bump `physicalSize` lên `Size(1080, 15400)` — đúng pattern đã ghi sẵn trong comment của chính helper đó (IDEA-59 lesson).

**Kết quả:**
- `flutter analyze` (example/, cả lib lẫn test): sạch.
- `flutter test --exclude-tags slow` (example/): **149/149 pass**, 0 regression (đã tự phát hiện + sửa 1 regression tiềm ẩn ở trên trước khi tính pass).
- Không đụng `lib/` root nên không cần chạy root analyze/test/api_compatibility.
- Không cần device smoke test (task cho phép bỏ qua, widget test đã verify đủ 3 nhánh nội dung thật).

**Tự chấm điểm: 9.5/10.** Trừ 0.5 vì chưa demo case "vừa hết hạn ReminderService thật sự bắn notification" (ngoài phạm vi — không có cách verify notification thật trong widget test), phần còn lại đúng yêu cầu, có TDD đầy đủ, tự phát hiện và sửa 1 regression thật trước khi commit.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-90-smart-reminder-haptic-sync-demo-in-example.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/smart_reminder_scheduling.dart`, `lib/core/haptic_choreographer.dart`, VÀ 2 file `example/lib/screens/widget_showcase_screen.dart`/`example/lib/screens/cookbook_screen.dart` (đọc bản MỚI NHẤT, cả 2 vừa được sửa nhiều lần trong session gần đây) trước khi thêm demo. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở `example/` (không đụng `lib/` nên không cần chạy root).
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 fork audit ĐỘC LẬP (khác phạm vi được giao) cùng phát hiện đúng gap này, và chính 2 task IDEA-62/IDEA-67 đã tự ghi nhận thiếu sót này trong lúc tự chấm điểm. Không trùng task nào trong `doc/task/done/`.
