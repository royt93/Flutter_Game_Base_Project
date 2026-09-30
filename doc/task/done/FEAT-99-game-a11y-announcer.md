---
id: FEAT-99
title: "Game accessibility announcer"
type: feature
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

File mới `lib/core/game_accessibility_announcer.dart`; tích hợp `lib/core/app_translations.dart`, `lib/core/game_event_bus.dart:22-51`, barrel `lib/roy_casual_kit.dart`.

## Hiện trạng

Kit có widget semantics nhưng không có coordinator announce event gameplay động. `GameEventBus` chỉ broadcast event; không adapter `SemanticsService.announce`, rate-limit/coalesce, locale formatting, hoặc no-op test seam.

## Vì sao cần / Hậu quả

Level-up/reward/lives thay đổi nhanh không được screen reader thông báo, hoặc consumer tự announce spam/overlap.

## Đề xuất

Adapter/service subscribe `GameEventBus`, map event → key `AppTranslations`, coalesce/rate-limit theo category, gọi injected announcer (production dùng `SemanticsService.announce`, test no-op/fake). Respect disable/reduced-motion/accessibility setting. Export qua barrel. Không trùng ENH-37/38, FEAT-76/82.

## Acceptance criteria

- [x] Unit test không platform channel: fake announcer nhận locale-aware text.
- [x] Burst level-up/reward/lives được coalesce/rate-limit, không spam.
- [x] Disabled/no-op path không gọi platform.
- [x] en/vi key parity pass.
- [x] Public export snapshot cập nhật có chủ đích.

## Quyết định

Đã chốt 3 quyết định kiến trúc qua `AskUserQuestion`:

1. **Generic event**: thêm `GameAccessibilityEvent extends GameEvent` (category + translationKey + parameters) thay vì hardcode/wire `LevelUpEvent`/`RewardGrantedEvent`/`LivesChangedEvent` vào 3 service ổn định — consumer tự `eventBus.emit(...)` đúng lúc game state đổi, announcer không tạo coupling ngược vào progression/reward/energy.
2. **Injected announce callback**: `GameAccessibilityAnnouncer` nhận `Future<void> Function(String)` thay vì gọi platform channel trực tiếp. Test dùng fake callback thu text; production consumer wire `SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr)` (API hiện hành thay `SemanticsService.announce` đã deprecated). Class không đụng platform channel trong test/runtime nếu consumer dùng fake/no-op seam.
3. **Leading-edge throttle theo category**: event đầu announce ngay; event cùng category trong `throttleWindow` (default 1500ms) bị drop; category khác vẫn announce ngay. Clock mặc định monotonic `Stopwatch`, có seam `nowMs` cho test deterministic.

Implementation: file mới `lib/core/game_accessibility_announcer.dart` gồm `GameAccessibilityCategory`, `GameAccessibilityEvent` (validate translationKey không rỗng, defensive-copy parameters), `GameAccessibilityAnnouncer` subscribe `GameEventBus`, locale mặc định theo `LocaleService.maybe.current` (fallback English), resolve key từ `AppTranslations`, interpolation `{key}`, leading throttle per-category, enabled mặc định theo `StorageKeys.gameA11yAnnouncerEnabled` (true), callback/platform lỗi bị nuốt, `dispose()` cancel subscription. Visual reduced-motion KHÔNG disable speech announcement (đó là hỗ trợ accessibility độc lập, không phải animation); consumer có thể override toàn bộ policy qua `isEnabled` seam. Thêm 3 key en/vi (`a11y_level_up`, `a11y_reward_granted`, `a11y_lives_changed`), export qua `lib/roy_casual_kit.dart`, regenerate `tool/api_snapshot.json` (additive-only, `Removed: {}`).

**Audit fork độc lập vòng 1: 7/10, tìm 2 gap thật**:

- `_onEvent` là async nhưng chỉ `announce()` nằm trong try/catch; throw từ 3 seam consumer-injected chạy trước đó (`isEnabled`/`locale`/`nowMs`) trở thành unhandled async zone error — `GameEventBus.subscribe`'s sync try/catch không bắt được Future error. Fix: bọc TOÀN BỘ async body trong try/catch. Thêm 3 test `runZonedGuarded` chứng minh từng seam throw không lọt ra ngoài.
- Interpolation cũ loop `replaceAll` tuần tự per-key, order-dependent: value chứa literal placeholder của key khác bị double-substitute (`{'value':'a {extra} b','extra':'Z'}`). Fix: 1 lần `RegExp.replaceAllMapped` trên template GỐC. Thêm regression test xác nhận giữ nguyên literal `{extra}` trong value.

Cả 4 test audit xác nhận đỏ trước fix, xanh sau. Rescore từ CÙNG fork: **9.5/10** — "Both confirmed gaps are resolved correctly... No new real defect found."

Test coverage: unit `test/core/game_accessibility_announcer_test.dart` **18 case** (en/vi/fallback, LocaleService mặc định, params, defensive-copy, per-category burst/boundary, enabled seam + StorageKey disabled, unknown key drop, dispose, callback/seam errors, constructor validation, audit double-substitution, parity); widget `test/widget/game_accessibility_announcer_test.dart` **5 case** qua host lifecycle thật (en, vi, burst throttle, disabled, dispose); integration/device `example/integration_test/app_boot_test.dart` **1 case** (app boot thật + event bus + vi locale + burst rate-limit + fake no-platform seam) — build/install/run pass trên Samsung A50s `SM_A507FN` (serial `R58MA6WYRPE`) theo lựa chọn user vì TECNO KJ7 mất kết nối hơn 20 phút.

Kết quả: `flutter analyze` sạch root + `example/`; accessibility quality gate sạch. New focused suites **23/23 pass**. `flutter test --exclude-tags slow`: root 2518/2519 với 1 timing flake tiền-tồn-tại ở `lifecycle_coordinator_test.dart` (hook timeout 5ms dưới full-suite load; file không bị sửa, chạy riêng case đó pass), example **197/197 pass**. Device FEAT-99 **1/1 pass**. API compatibility additive-only + snapshot cập nhật.

Tự chấm ban đầu 9/10 → audit vòng 1 7/10 (2 gap thật) → fix + regression tests → audit vòng 2 **9.5/10**.

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

Cao. Đã verify `GameEventBus.subscribe<T>` trả StreamSubscription và dispose API; grep `lib/core` không có announcer/a11y service. `AppTranslations` có en/vi maps. Không trùng existing accessibility tasks theo done file IDs.
