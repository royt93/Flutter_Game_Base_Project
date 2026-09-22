---
id: BUG-46
title: "EnergyService ghi state qua unawaited(_writeState(...)) trần, không có save-chain guard như 7 service anh em"
type: bug
priority: P1
effort: S
source: "Fork nội bộ (audit lib/core/*.dart), verify lại qua Read lib/core/energy_service.dart:78-90,140-146,193"
---

## Vị trí
`lib/core/energy_service.dart` — `consumeEnergy()` (dòng ~78-90) và `_regen()` (dòng ~140-146), cả 2 dùng `unawaited(_writeState(...))` (dòng 193) trực tiếp.

## Hiện trạng
Không giống 7 service ledger cùng họ (`AchievementService`, `DailyLoginService`, `DailyQuestService`, `LocalScoreboardService`, `OnboardingCoordinatorService`, `PurchaseLedgerService`, `SaveSlotManager`, `SeasonEventService` — đã có `_saving`/`_saveChain` guard, dù bản thân guard đó cũng đang bị race theo BUG-45), `EnergyService` hoàn toàn KHÔNG có bất kỳ guard nào — cả `consumeEnergy` và `_regen` gọi thẳng `unawaited(_writeState(...))`.

## Vì sao cần / Hậu quả
Gọi `consumeEnergy()` 2 lần liên tiếp không `await` (double-tap dùng năng lượng trong game) tạo 2 write future chạy song song không có thứ tự đảm bảo — future ghi SAU (theo thời gian I/O thật, không phải thứ tự gọi) có thể chứa state CŨ hơn nếu future đầu chậm hơn. Restart app sau đó, energy count có thể rollback về giá trị cũ hơn — người chơi lợi dụng để farm năng lượng miễn phí bằng double-tap liên tục.

## Đề xuất
Thêm `_saveChain`/`_scheduleSave()` (dùng đúng helper chung sẽ tạo ở BUG-45 nếu 2 task được làm cùng đợt; nếu làm độc lập trước, viết inline giống pattern hiện có ở `PurchaseLedgerService`/`SaveSlotManager`), thay `unawaited(_writeState(...))` bằng `_scheduleSave()` ở cả 2 call site.

## Acceptance criteria
- [ ] `consumeEnergy()` gọi 2 lần liên tiếp không await — ghi disk theo đúng thứ tự gọi, không bị race đảo ngược.
- [ ] `_regen()` và `consumeEnergy()` gọi xen kẽ nhau (regen đang ghi, consume gọi ngay sau) vẫn ghi đúng thứ tự, không mất write nào.
- [ ] Hành vi trả về (giá trị `count` sau `consumeEnergy`) không đổi so với hiện tại trong trường hợp không có race.
- [ ] Test race cụ thể verify bằng cách kiểm soát thứ tự resolve của 2 Future ghi song song.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-46-energy-service-missing-save-chain-guard.md` này trước khi làm. Đọc toàn bộ `lib/core/energy_service.dart` và tham khảo pattern `_saving`/`_saveChain` ở `lib/core/purchase_ledger_service.dart`/`lib/core/save_slot_manager.dart` (lưu ý: pattern đó tự nó cũng có 1 race hẹp khác, xem `BUG-45` — không bắt buộc phải làm chung 1 lúc, nhưng nếu BUG-45 đã xong trước, dùng đúng helper `_scheduleSave()` chung của BUG-45 thay vì tự viết lại `_saving` boolean cũ). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device Android thật khuyến khích (double-tap nút tiêu năng lượng trong `WidgetShowcaseScreen`/`CookbookScreen` nếu có demo `EnergyService`, verify không rollback) nhưng không bắt buộc nếu chỉ verify được qua unit test race.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp `energy_service.dart`, xác nhận cả 2 call site dùng `unawaited(_writeState(...))` trần, grep xác nhận không có `_saving`/`_saveChain` nào trong file. Không trùng task nào trong `doc/task/done/`.
