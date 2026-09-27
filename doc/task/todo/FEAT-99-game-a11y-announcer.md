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

- [ ] Unit test không platform channel: fake announcer nhận locale-aware text.
- [ ] Burst level-up/reward/lives được coalesce/rate-limit, không spam.
- [ ] Disabled/no-op path không gọi platform.
- [ ] en/vi key parity pass.
- [ ] Public export snapshot cập nhật có chủ đích.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

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
