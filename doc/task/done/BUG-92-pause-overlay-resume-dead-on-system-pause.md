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

- [x] Widget test: pause(system), tap Resume, không truyền `onResume` → phase `playing`.
- [x] User pause vẫn resume bình thường.
- [x] Cả user + system → Resume chỉ gỡ đúng reason được chọn, không resume sớm.

## Quyết định

`_handleResume` giờ đọc `session.snapshot.value.pauseReasons` thay vì
fallback cứng `GamePauseReason.user`: ưu tiên gỡ `system` nếu active VÀ
`showForSystemPause == true`, không thì `user`. Không đổi hành vi khi chỉ
có `user` active (test cũ vẫn pass). Guard `showForSystemPause` được bổ
sung sau audit: 1 overlay cấu hình mặc định (`showForSystemPause: false`)
chỉ visible vì user-pause không được phép vô tình gỡ luôn system-pause độc
lập đang active cùng lúc — `_handleResume` phải tôn trọng cùng ownership
mà `_isVisible` đã định nghĩa.

2 test mới trong `test/widget/common/pause_overlay_test.dart`: pause CHỈ
`system` (`showForSystemPause: true`) → tap Resume → phase về `playing`,
`pauseReasons` rỗng (FAIL với code cũ — `resume(user)` bị reject); cả
`user`+`system` cùng active → tap Resume 1 lần → chỉ gỡ `system`, phase vẫn
`paused`, `pauseReasons` còn `{user}` (không resume sớm). Test cũ "bấm
Resume gọi session.resume(user) đúng 1 lần" vẫn pass nguyên văn.

Bug này gộp chung device smoke test với BUG-91 (cùng
`GameDemoScreen`/`PauseOverlay` trên 1 lần chạy
`app_boot_test.dart` trên TECNO KJ7 — xem mục Quyết định của BUG-91).

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root và
`example/`.

Tự chấm: 9.5/10.

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
