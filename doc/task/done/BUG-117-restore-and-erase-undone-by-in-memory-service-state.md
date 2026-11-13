---
id: BUG-117
title: "Restore (importAll) và erase (eraseAll) bị đảo ngược bởi trạng thái trong bộ nhớ của các service"
type: bug
layer: lib/core (StorageService + EconomyWallet, PurchaseLedgerService, EnergyService, InventoryService, PlayerProgressionService...)
priority: P1
effort: M
source: "Scan SDK 2026-11-13 (fork); tái hiện độc lập một phần bằng PlayerDataRightsService"
---

## Vấn đề
Các service nạp dữ liệu từ `StorageService` MỘT lần (`onInit`/`_hydrate`) rồi giữ bản sao trong bộ nhớ. `StorageService.importAll`, `eraseAll`, `importWithPrefix` ghi thẳng xuống storage và không báo cho service nào. Lần ghi kế tiếp của service ghi lại bản sao cũ (cộng thay đổi mới) đè lên dữ liệu vừa khôi phục hoặc vừa xoá.

## Tái hiện của tôi (đã chạy, test tạm đã xoá)
`PlayerDataRightsService.requestErasure()` sau khi ví có 777 coin: ví MỚI đọc 0 (storage đã sạch), nhưng ví cũ (đang chạy) vẫn báo 777 trong bộ nhớ; sau `earn(gem, 1)`, ví mới đọc **coin 777 + gem 1**: số dư đã xoá sống lại. Fork cũng báo (chưa chạy lại bởi tôi): restore từ backup 100 coin về trong khi bộ nhớ đang 1000, sau một `earn(1)` thì ví mới đọc 1001 thay vì 101; ledger 510 về 10 rồi ra 511; `EnergyService.currentEnergy` vẫn 3 sau `eraseAll`.

## Tác động
`BackupRestorePanel` (`backup_restore_panel.dart:155` gọi `importAll`) và `PlayerDataRightsService.requestErasure` (`:117`) trông như hoạt động, nhưng bị đảo ngược ở lần ghi kế tiếp. Một yêu cầu xoá dữ liệu (GDPR) có thể làm sống lại số dư đã xoá. Tài liệu hiện không nói cần khởi động lại.

## Phương án (cần chọn, đây là quyết định thiết kế)
1. **Hook làm mới:** `StorageService` phát một tín hiệu (ví dụ `ValueNotifier<int> epoch` tăng sau `importAll`/`eraseAll`/`importWithPrefix`/`removeAllWithPrefix`); mỗi service nghe và gọi lại `_hydrate()`. Ưu: sửa tận gốc, không cần restart. Nhược: chạm ~9 service, cần test từng cái và xử lý ghi dở đang chờ.
2. **Ghi nhận cần khởi động lại:** `BackupRestorePanel` và `requestErasure` kết thúc bằng yêu cầu app khởi động lại/`Get.reset` + đăng ký lại, ghi rõ trong doc và trả cờ `restartRequired`. Ưu: nhỏ, ít rủi ro. Nhược: vẫn có cửa sổ ghi trước khi restart, và dựa vào consumer làm đúng.
3. **Service đọc lại trước khi ghi (read-modify-write từ storage):** mỗi lần ghi hydrate lại từ storage. Ưu: không cần hook. Nhược: đổi hành vi hot path, ảnh hưởng hiệu năng và các test sync.

## Khuyến nghị
Phương án 1 cho các service tiền tệ/xoá dữ liệu trước (wallet, ledger, inventory, progression, energy), vì GDPR và tiền là hậu quả nặng nhất; phương án 2 như lớp bảo vệ ngay cho `requestErasure`.

## Đã sửa (2026-11-14), phương án 1: hook làm mới
`StorageService.replaceEpoch` (`ValueNotifier<int>`) tăng sau `importAll` (và vì vậy `eraseAll`), `importWithPrefix`, `removeAllWithPrefix` thành công (một lần `importAll` lỗi và rollback thì không tăng). Mọi service giữ bản sao trong bộ nhớ lắng nghe:
- Hydrate lại bằng `_hydrate()` kèm dọn sạch khi key không còn: `EconomyWallet`, `InventoryService`, `PlayerProgressionService` (cũng gắn trong constructor vì chúng hydrate ở đó, BUG-40; thêm `onClose` để gỡ listener). Trước đây `_hydrate` thoát sớm khi `raw == null` mà không dọn bản sao.
- Bỏ bản sao lazy bằng mixin `StorageReplaceWatch` (`lib/core/utils/storage_replace_watch.dart`), gắn lúc lần đầu nạp: `PurchaseLedgerService`, `DailyLoginService`, `DailyQuestService`, `SeasonEventService`, `LocalScoreboardService`, `AchievementService`, `EnergyService` (bỏ `_latestState`).
Test: `test/core/storage_replace_reload_test.dart` (8 test: ledger restore/erase, energy, inventory, progression, scoreboard, achievement, wallet) và 3 test BUG-117 trong `economy_wallet_test.dart`; **8/8 đỏ khi hoàn nguyên lib, xanh khi có**. `test/core` 2048 test, 1603 test widget, 442 test example, API gate (`unchanged` sau regenerate snapshot) và các quality gate đều xanh.

## Giới hạn đã biết (chưa xử lý)
- Ghi đang chờ (`_scheduleSave` đã xếp hàng) lúc `eraseAll` chạy vẫn có thể ghi xuống sau khi erase; hàng đợi ghi của từng service không bị huỷ. Cửa sổ rất hẹp nhưng chưa được kiểm.
- Chỉ phủ các service giữ bản sao nạp từ storage. Service khác của consumer tự giữ state vẫn phải nghe `StorageService.replaceEpoch` (API công khai mới, ghi trong CHANGELOG).
- `SaveSlotManager` (metadata slot) chưa kiểm.

## Tiêu chí xong
Test: sau `eraseAll()`/`importAll(backup)`, một lần ghi tiếp theo KHÔNG làm sống lại dữ liệu cũ (ví, ledger, energy, inventory, progression). Cần người dùng chọn phương án trước khi sửa.
