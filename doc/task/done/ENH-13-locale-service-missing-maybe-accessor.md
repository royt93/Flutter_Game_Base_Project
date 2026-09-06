---
id: ENH-13
title: "LocaleService thiếu static .maybe accessor (duy nhất trong lib/core/ chưa có)"
type: enhance
priority: P2
effort: S
verified: true
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Hiện trạng
Mọi `GetxService` khác trong `lib/core/` (`AudioManager`, `AchievementService`,
`DailyLoginService`, `EnergyService`, `OfflineProgressionService`,
`PerformanceTierService`, `ReminderService`, `RemoteConfigService`,
`StorageService`) đều có `static X? get maybe`. `LocaleService` là service
duy nhất chưa có — call site (vd `DebugQaOverlay`) phải tự viết
`Get.isRegistered<LocaleService>() ? Get.find<LocaleService>() : null` thủ
công thay vì gọi `LocaleService.maybe`.

## Đề xuất
Thêm `static LocaleService? get maybe => Get.isRegistered<LocaleService>()
? Get.find<LocaleService>() : null;` vào `lib/core/locale_service.dart`,
đúng pattern đã có ở mọi service khác. Cập nhật `DebugQaOverlay` dùng accessor
mới thay vì tự viết `Get.isRegistered` inline.

## Acceptance criteria
- [ ] `LocaleService.maybe` tồn tại, cùng pattern các service khác.
- [ ] Test: null khi chưa `Get.put`, đúng instance khi đã đăng ký.
- [ ] `DebugQaOverlay` dùng `LocaleService.maybe` thay vì tự viết
      `Get.isRegistered` inline.
