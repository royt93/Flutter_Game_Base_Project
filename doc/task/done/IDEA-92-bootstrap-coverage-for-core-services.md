---
id: IDEA-92
title: "Bootstrap chỉ phủ 7 module trong khi lib/core có 38 file chứa GetxService"
type: idea
layer: lib/core/kit_bootstrap
priority: P3
effort: M
source: "Scan SDK 2026-11-12: enum RoyCasualKitModule có 7 giá trị (kit_bootstrap.dart:15)"
---

## Quan sát
`CLAUDE.md` khuyên dùng `RoyCasualKit.initialize` thay `Get.put`, nhưng phần lớn service (wallet, energy, quest, daily login...) consumer vẫn phải tự đăng ký và tự reset, nên `resetForTesting` không dọn được chúng.

## Cần làm trước khi quyết
Phân loại từng service: cần tham số bắt buộc (không tự đăng ký được, ví dụ `OfflineProgressionService`) hay đăng ký không tham số (có thể thành module). Chỉ với nhóm sau mới đáng thêm module.

## Rủi ro
Đây có thể là thiết kế có chủ ý để consumer kiểm soát tham số; kết quả phân loại có thể là "không làm". Xác nhận với partner trước khi mở rộng enum (thay đổi API công khai).

## Ghi chú
Đếm `onClose`/`dispose` bằng grep ở ít nhất 12 service cho 0 lần khớp, nhưng chưa chứng minh service nào giữ timer/stream thật; không tách task riêng cho đến khi có bằng chứng rò.

## Kết quả phân loại (2026-11-17, chỉ đọc, không đổi code)
Đếm bằng regex trên `lib/core/*.dart`: 38 class `extends GetxService/GetxController`. Là heuristic, chưa chạy thử đăng ký từng service.
- **14 có tham số bắt buộc, không tự đăng ký được:** `AppVersionGateController` (remoteConfig), `AssetPreloadCoordinator` (loader), `CheckpointCoordinator` (storage, snapshot, restore), `ConnectivityCoordinator` (signal, probe), `ConsentStateService` (policyVersion), `DeepLinkCommandRouter` (routes), `EconomyWallet` (storage), `InventoryService` (storage, itemCatalog), `OfflineOutboxService` (storage, uploader), `PlayerProgressionService` (storage, đường cong cấp), `PrestigeService` (wallet), `RemoteConfigService` (assetPath), `RemoteKillSwitchController` (remoteConfig), `RewardTransactionPipeline` (wallet).
- **24 không có tham số bắt buộc.** 7 đã là module (`StorageService`, `LocaleService`, `AudioManager`, `ReminderService`, `PerformanceTierService`, `RoyLifecycleCoordinator`, `WakeLockService`). **Còn 17 ứng viên:** `AchievementService`, `AppSessionTracker`, `DailyLoginService`, `DailyQuestService`, `EnergyService`, `ExperimentBucketingService`, `GameSessionController`, `GameTimeController`, `LocalScoreboardService`, `OfflineProgressionService`, `OnboardingCoordinatorService`, `PersistentCooldownService`, `PlatformCapabilityRegistry`, `PurchaseLedgerService`, `ReplayRecorder`, `SaveSlotManager`, `SeasonEventService`.
- **Nhưng "không bắt buộc" không có nghĩa là mặc định đúng:** `EnergyService` (maxEnergy 5, refill 30 phút), `OfflineProgressionService` (trần 8 giờ), `LocalScoreboardService` (capacity 50), `AppSessionTracker` (timeout 30 phút) là tham số thiết kế game. Đăng ký ngầm bằng mặc định có thể che việc consumer chưa chọn giá trị. Phần lớn 17 ứng viên cũng cần `StorageService` đã đăng ký trước (đúng thứ tự module).
- **Bằng chứng rò tài nguyên: không có.** 7 service giữ `Timer`/`StreamSubscription`/`StreamController`/listener (`AchievementService`, `ConnectivityCoordinator`, `EconomyWallet`, `InventoryService`, `OfflineOutboxService`, `PlayerProgressionService`, `RewardTransactionPipeline`) đều có `onClose`. Ghi chú cũ "12 service 0 `onClose`" đúng nhưng các service đó không giữ timer/stream theo regex.
- **`resetForTesting` hiện chỉ dọn service SDK sở hữu** (`_owned`) cộng lại `NeonTheme` (palette, dark, colorBlindSafe). Service consumer tự `Get.put` không bị dọn, là thiết kế hiện hành.
- Chưa xác nhận với partner; thêm giá trị vào `RoyCasualKitModule` là đổi API công khai (cần `api_compatibility snapshot` và CHANGELOG).

## Quyết định (2026-11-17, người dùng): đóng, không mở rộng `RoyCasualKitModule`
Lý do: 14/38 service cần tham số bắt buộc; nhóm không bắt buộc nhiều cái mang tham số thiết kế game nên đăng ký ngầm bằng mặc định có thể che việc consumer chưa chọn; không có bằng chứng rò tài nguyên; đổi enum là đổi API công khai khi chưa có nhu cầu từ đối tác. Mở lại nếu có consumer thật yêu cầu `resetForTesting` dọn service của họ.
