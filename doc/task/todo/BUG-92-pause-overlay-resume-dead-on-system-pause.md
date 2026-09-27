---
id: BUG-92
title: "PauseOverlay Resume chết khi chỉ có system pause"
type: bug
priority: P0
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/presentation/widgets/common/pause_overlay.dart:88` `_handleResume`; `lib/core/game_session_controller.dart:75` `resume`.

## Hiện trạng

Overlay hiện cho system reason nếu `showForSystemPause`, nhưng `_handleResume` fallback luôn `session.resume(GamePauseReason.user)`. Với pause thuần system, `resume(user)` bị reject do set không có user (controller dòng 77-80), nút Resume không tác dụng.

## Vì sao cần / Hậu quả

User quay lại app đang system-paused có màn pause nhưng không thể tiếp tục game.

## Đề xuất

`_handleResume` đọc active pause reason: ưu tiên system nếu có, fallback user; giữ `onResume` override hiện tại.

## Acceptance criteria

- [ ] Widget test: pause(system), tap Resume, không truyền `onResume` → phase `playing`.
- [ ] User pause vẫn resume bình thường.
- [ ] Cả user + system → Resume chỉ gỡ đúng reason được chọn, không resume sớm.

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

Cao. Đã verify visibility accepts system reason, fallback resume luôn user dòng 88-95, controller reject reason không active dòng 75-89.
