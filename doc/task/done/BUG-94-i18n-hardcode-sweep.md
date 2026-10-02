---
id: BUG-94
title: "i18n hardcode sweep"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/presentation/widgets/common/pause_overlay.dart:143,159`; `lib/presentation/widgets/common/tutorial_sequence.dart:192`; `example/lib/screens/game_demo_screen.dart:76,332,456`.

## Hiện trạng

Literal English còn sót: default `Paused/Resume/Restart/Quit`, `Skip`, round `Spend...`, HUD `gems...`, achievement banner `Achievement Unlocked...`.

## Vì sao cần / Hậu quả

Locale vi hiển thị lẫn English; test parity không bắt được literal không qua `AppTranslations`.

## Đề xuất

Thêm key en+vi vào `AppTranslations`, thay mọi literal; giữ test key parity; grep literal cũ rỗng.

## Acceptance criteria

- [x] Test key parity pass cho mọi key mới.
- [x] Grep literal cũ trong source/widget/example rỗng.
- [x] Screenshot/widget test không phụ thuộc locale cố định cho label đã đổi.

## Quyết định

- **Implementation**: Thêm đủ key en/vi cho Pause/Tutorial/Spotlight/LevelUp/GameDemo; dùng GetX `@param` đúng cho `.trParams`, giữ `{value}` cho announcer resolver riêng. Default constructor label chuyển nullable và resolve `.tr` lúc build để đổi locale runtime đúng. Fresh install luôn English, không theo OS locale; đã cập nhật `CLAUDE.md` theo quyết định sản phẩm global.
- **TDD & Test coverage**: Key parity + placeholder parity; widget tests en/vi cho Pause/Tutorial/Spotlight/LevelUp/GameDemo; custom overrides giữ nguyên; device test mở GameDemo vi, kiểm tra status/HUD/button/PauseOverlay và không còn English.
- **Phân tích/test**: Grep literal cũ rỗng; root 2537/2537 pass, example 200/200 pass; analyze sạch. Device test BUG-94 pass trên TECNO KJ7.
- **Audit**: Fork độc lập review toàn cụm đạt 9.8/10, không finding i18n/default-locale.

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

Cao. Đã verify `title ?? 'Paused'`, `skipLabel = 'Skip'`, `_roundStatus = 'Spend...'`, HUD `'gems:...'`, banner achievement English.
