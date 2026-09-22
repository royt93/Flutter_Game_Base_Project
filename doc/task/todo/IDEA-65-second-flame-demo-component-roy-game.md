---
id: IDEA-65
title: "RoyGame chỉ có 1 component tap-toggle — thêm ví dụ collision/camera-follow để chứng minh Flame wiring đầy đủ hơn"
type: idea
priority: low
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/presentation/game/roy_game.dart`, `test/presentation/game/roy_game_test.dart`.

## Hiện trạng
`RoyGame` hiện chỉ có 1 component tap-toggle (`TappableCircle` theo mô tả CLAUDE.md) — không có ví dụ collision detection (`HasCollisionDetection`) hay camera-follow. Đây là điểm chứng minh duy nhất "Flame wiring end-to-end hoạt động thật" của cả package.

## Vì sao cần / Hậu quả
Thiếu các pattern cơ bản này khiến người dùng kit phải tự mò tài liệu Flame thay vì học từ ví dụ có sẵn trong chính package họ đang dùng.

## Đề xuất
Thêm 1 component thứ 2 minh hoạ collision detection đơn giản (2 component va chạm, đổi màu/kích hoạt hiệu ứng khi chạm) hoặc camera-follow (camera bám theo 1 component di chuyển).

## Acceptance criteria
- [ ] `RoyGame` có thêm ít nhất 1 component minh hoạ collision HOẶC camera-follow (chọn 1, không cần cả 2 nếu effort không cho phép).
- [ ] `test/presentation/game/roy_game_test.dart` verify component mới hoạt động đúng (dùng pattern `tester.pump(Duration(...))` bounded theo ghi chú CLAUDE.md, không `pumpAndSettle`).
- [ ] Không phá component `TappableCircle` hiện có.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-65-second-flame-demo-component-roy-game.md` này trước khi làm. Đọc toàn bộ `lib/presentation/game/roy_game.dart` và `test/presentation/game/roy_game_test.dart` (ghi chú CLAUDE.md về Ticker không settle) trước khi thêm component mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ Flame/widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (mở `GameDemoScreen`, verify component mới hoạt động mượt) không bắt buộc nếu Flame test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — mô tả hiện trạng `RoyGame` khớp với CLAUDE.md (chỉ 1 component). Không trùng task nào trong `doc/task/done/`. Trùng lặp 1 phần scope với ENH-81 (pooled component) — nếu cả 2 được chọn, cân nhắc gộp implement chung 1 lần (component mới VỪA minh hoạ collision VỪA dùng pooling) để tránh sửa `RoyGame` 2 lần riêng lẻ.
