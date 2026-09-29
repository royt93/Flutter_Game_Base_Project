---
id: BUG-93
title: "Example wiring sweep"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

(a) `example/lib/screens/game_demo_screen.dart:145`; (b) `lib/presentation/widgets/common/achievement_unlock_listener.dart:50`; (c) `example/lib/screens/widget_showcase_screen.dart:468`.

## Hiện trạng

(a) `_eventBus.subscribe<CircleTappedEvent>` trả `StreamSubscription`, bị vứt; dispose chỉ dispose bus dòng 235 nhưng không thấy cancel subscription event bus. (b) listener subscribe 1 lần `initState`, không `didUpdateWidget`; `review_prompt_trigger.dart:83` đã có mẫu resubscribe. (c) asset session dùng `GameSessionController()` trần, game demo đã cảnh báo phải Get.put để `onInit` chạy.

## Vì sao cần / Hậu quả

Leak subscription, stream thay đổi mất event, session lifecycle không chạy khi thiếu wiring đúng.

## Đề xuất

(a) giữ subscription và cancel trước dispose bus; (b) thêm `didUpdateWidget` resubscribe; (c) dùng cùng lifecycle registration như game demo.

## Acceptance criteria

- [x] Mỗi mục có ít nhất 1 widget/unit test chứng minh cleanup/resubscribe/registration.
- [x] Không double-cancel/free-after-dispose trong dispose path.

## Quyết định

(a) `example/lib/screens/game_demo_screen.dart`: subscription từ `_eventBus.subscribe<CircleTappedEvent>` giờ lưu vào field `_tapSub`, cancel trong `dispose()` TRƯỚC khi dispose bus (cùng thứ tự `_unlockSub` đã có sẵn). Thêm optional `GameDemoScreen({eventBus})` test seam + cờ `_ownsEventBus` — screen chỉ tự `dispose()` bus nó tự tạo, không đóng bus do caller inject (để test verify riêng biệt cleanup subscription vs cleanup bus). Thêm `GameEventBus.hasListeners` (getter debug nhỏ, additive) để test/consumer verify subscription thực sự đã cancel thay vì chỉ suy đoán qua `emit()` no-op sau dispose.

(b) `lib/presentation/widgets/common/achievement_unlock_listener.dart`: thêm field `_service` theo dõi identity `AchievementService` đang subscribe; `_subscribeToCurrentService()` gọi ở cả `initState` VÀ `didUpdateWidget` — nếu `AchievementService.maybe` đổi (kể cả null → có service, hoặc service A → service B), cancel subscription cũ rồi subscribe lại đúng instance mới. Không double-cancel vì `dispose()` chỉ cancel 1 lần cuối, độc lập với vòng resubscribe.

(c) `example/lib/screens/widget_showcase_screen.dart`: `_assetSession` đổi từ `GameSessionController()` constructor trần sang `Get.put<GameSessionController>(GameSessionController.withHookName(lifecycle: RoyLifecycleCoordinator.maybe, hookName: _assetSessionTag), tag: _assetSessionTag)` — `onInit()` giờ thực sự chạy (đăng ký lifecycle hook thật), dispose dùng `Get.delete(tag:)` thay vì gọi `onClose()` trần.

**Audit fork độc lập tìm 1 gap thật** (vòng 1, 8.5/10): `GameSessionController.onInit`/`onClose` dùng hook name CỐ ĐỊNH `'game-session'` — nếu 2 instance (GameDemoScreen's untagged session + WidgetShowcase's tagged session) cùng chia sẻ 1 `RoyLifecycleCoordinator`, `removeHook` (match theo tên, không theo instance) của 1 instance sẽ xoá nhầm hook của instance kia. Chưa xảy ra được qua luồng navigation hiện tại (Home → 1 trong 2 màn hình, không stack cả 2), nhưng là gap thật fix này vừa làm "reachable-adjacent". Đã fix bằng named constructor mới, hoàn toàn additive: `GameSessionController.withHookName({lifecycle, required hookName})` (validate `hookName` không rỗng, throw `ArgumentError` — đúng convention ENH-85), field `hookName` mới (constructor mặc định giữ nguyên, tự set `hookName = 'game-session'` để không đổi hành vi cũ). `onInit`/`onClose` dùng `hookName` thay vì literal. WidgetShowcase's `_assetSession` chuyển sang dùng named constructor với `hookName: _assetSessionTag` (duy nhất, khớp Get tag). Rescore vòng 2 từ CÙNG fork: **9.5/10** — "Gap confirmed resolved... No new defect found — clean, minimal, correctly scoped fix."

TDD: viết test đỏ trước cho cả 3 case + case audit-fix, verify fail đúng lý do (bao gồm việc phát hiện `didChangeAppLifecycleState` dispatch async cần `await Future<void>.delayed(Duration.zero)` trước khi assert), rồi implement tới khi xanh.

Test coverage: unit (`test/core/game_session_controller_test.dart`: 3 case mới — default constructor tái hiện đúng hiện tượng collision (tài liệu hoá giới hạn có chủ đích của constructor mặc định), `withHookName` cô lập đúng 2 instance khác hookName, `hookName` rỗng throw `ArgumentError`), widget (`example/test/game_demo_screen_test.dart`: dispose cancel subscription trên bus caller inject, bus vẫn mở nhưng hết listener; `test/widget/common/achievement_unlock_listener_test.dart`: 2 case — service đăng ký muộn + rebuild vẫn nhận unlock, service bị thay thế + rebuild resubscribe đúng stream mới; `example/test/widget_showcase_screen_test.dart`: asset session Get.put đúng tag, `onInit` chạy thật, lifecycle background/resume qua đúng hook, dispose Get.delete đúng tag), integration/device (`example/integration_test/app_boot_test.dart`: 1 case — navigate GameDemo (tap tạo subscription, back → hasListeners false), navigate WidgetShowcase (tag session registered+initialized, back → unregistered+closed), chạy trên thiết bị Android thật TECNO KJ7, pass — phải sửa `Get.back()` đơn lẻ thành vòng lặp `while (find...isNotEmpty)` vì transition animation thật trên device cần nhiều hơn 1 pump để hoàn tất route pop).

Kết quả: `flutter analyze` sạch root + `example/`. `flutter test --exclude-tags slow` sạch root (2493/2493, không flake lần chạy này) + sạch `example/` (197/197). `dart run tool/api_compatibility.dart check` báo `additive` (`GameSessionController.withHookName` + `GameEventBus.hasListeners` mới, `Removed: {}`), snapshot đã regenerate. Smoke test device thật TECNO KJ7 pass — riêng lần chạy full suite trên device có 1 flake ở `FEAT-33` (test không liên quan, đã verify lại riêng lẻ pass, cùng lớp timing-race giữa OS lifecycle event thật và simulated trigger đã ghi nhận từ trước, không phải regression).

Tự chấm ban đầu 9/10 (đã có 3 fix + test đầy đủ trước khi audit) → audit fork độc lập vòng 1 tìm 1 gap thật (hook name collision) → fix → rescore vòng 2: **9.5/10**.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao với (a) và (c); (b) verify initState subscribe dòng 50, không có `didUpdateWidget`, mẫu review prompt dòng 83 đã đúng. Riêng (a): `_unlockSub` dùng cho achievement stream; subscribe event bus trả về nhưng context chưa giữ.
