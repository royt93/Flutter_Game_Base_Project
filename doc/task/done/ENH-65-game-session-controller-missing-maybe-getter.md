---
id: ENH-65
title: "GameSessionController: bổ sung .maybe getter — service duy nhất trong lib/core/ còn thiếu"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog audit — grep toàn bộ `lib/core/*.dart` cho pattern `.maybe`)
---

## Vị trí
Mở rộng — `lib/core/game_session_controller.dart` (`GameSessionController`).

## Hiện trạng
Mọi `GetxService`/`GetxController` trong `lib/core/` đều có sẵn 1 static getter `.maybe` (dùng để lấy instance nếu đã đăng ký, trả về `null` an toàn nếu chưa — tiện cho test/widget không muốn phụ thuộc cứng vào `Get.find` throw). Xác nhận bằng cách đếm trực tiếp:

```
for f in lib/core/*.dart; do
  grep -q "extends GetxService\|extends GetxController" "$f" && \
  echo "$f: $(grep -c 'static .*get maybe' "$f")"
done
```

Kết quả: **18/19 service có đúng 1 `.maybe` getter** (`AchievementService`, `AudioManager`, `DailyLoginService`, `DailyQuestService`, `EconomyWallet`, `EnergyService`, `ExperimentBucketingService`, `RoyLifecycleCoordinator`, `LocalScoreboardService`, `LocaleService`, `OfflineProgressionService`, `OnboardingCoordinatorService`, `PerformanceTierService`, `PurchaseLedgerService`, `ReminderService`, `RemoteConfigService`, `ReplayRecorder`, `SeasonEventService`, `StorageService`) — CHỈ DUY NHẤT `GameSessionController` (`lib/core/game_session_controller.dart`) có **0**.

## Vì sao cần / Hậu quả
Đây là lỗ hổng nhất quán API rõ ràng nhất trong toàn bộ `lib/core/` — 1 consumer app hoặc 1 widget test muốn kiểm tra "game session đã khởi tạo chưa" mà không muốn `Get.find<GameSessionController>()` throw khi chưa `Get.put` (kịch bản rất thường gặp: 1 widget con hiện UI khác nhau tuỳ game đã bắt đầu session hay chưa, hoặc 1 test không cần setup đầy đủ session) phải tự viết `Get.isRegistered<GameSessionController>() ? Get.find<GameSessionController>() : null` thủ công thay vì gọi `GameSessionController.maybe` như MỌI service khác trong package — bất nhất, dễ gây nhầm lẫn khi đọc code giữa các service.

## Đề xuất
Thêm đúng 1 static getter, khớp 100% pattern đã dùng ở 18 service còn lại (ví dụ copy nguyên xi từ `AchievementService.maybe`):

```dart
/// Gets the instance if already registered (safe to call from
/// game/widget tests).
static GameSessionController? get maybe =>
    Get.isRegistered<GameSessionController>()
    ? Get.find<GameSessionController>()
    : null;
```

Không đổi bất kỳ hành vi nào khác của `GameSessionController` (transition logic, `restart()` từ ENH-61, lifecycle hook wiring).

## Acceptance criteria
- [x] `GameSessionController.maybe` trả về `null` khi chưa `Get.put`, không throw.
- [x] `GameSessionController.maybe` trả về đúng instance đã đăng ký khi đã `Get.put`.
- [x] Không đổi hành vi bất kỳ method nào khác (`markReady`/`start`/`pause`/`resume`/`win`/`lose`/`restart`); không phá test cũ trong `test/core/game_session_controller_test.dart`.
- [x] Test: 2 test mới (case null, case có instance) — khớp đúng pattern test `.maybe` đã dùng ở các service khác (ví dụ `test/core/achievement_service_test.dart`'s `.maybe` test group).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-65-game-session-controller-missing-maybe-getter.md` này trước khi làm. Đọc `lib/core/game_session_controller.dart` toàn bộ và đối chiếu với cách `.maybe` được viết ở 1-2 service khác (ví dụ `lib/core/achievement_service.dart`, `lib/core/daily_quest_service.dart`) để copy đúng format/doc-comment convention. Implement bằng TDD (viết test fail trước — gọi `GameSessionController.maybe` khi chưa tồn tại method này sẽ compile-error, đó là "test fail" hợp lệ cho trường hợp thêm API mới — rồi thêm getter cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng khớp pattern `.maybe` đã dùng nhất quán trong toàn repo, không phá API/test hiện có, không thêm gì thừa ngoài đúng 1 getter).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/` (thay đổi core service thuần, không có UI liên quan trực tiếp) — không cần device smoke test.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — xác nhận bằng đếm trực tiếp qua grep trên TOÀN BỘ 19 file `GetxService`/`GetxController` trong `lib/core/`: 18/19 có đúng 1 `.maybe`, `GameSessionController` có 0. Đây là task nhỏ nhất có thể (effort XS, đúng 1 getter thuần, copy pattern đã có sẵn 18 lần trong chính repo này) — rủi ro gần như bằng 0, không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Copy nguyên xi pattern `.maybe` từ `AchievementService` — đúng 1 getter, không đổi gì khác.

**Test:** 2 test mới trong `test/core/game_session_controller_test.dart` nhóm "ENH-65" — null khi chưa `Get.put`, đúng instance khi đã đăng ký. Không phá 9 test cũ.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1156/1156 pass.

**Tự chấm điểm: 10/10** — đúng chính xác pattern đã dùng nhất quán 18 lần khác trong repo, không thêm gì thừa, rủi ro bằng 0.
