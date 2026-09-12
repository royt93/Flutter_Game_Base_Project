---
id: ENH-46
title: "Thêm onTap cho LeaderboardEntry và AvatarFrame (hiện chỉ hiển thị, không tương tác được)"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/leaderboard_list.dart` (`LeaderboardEntry`), `lib/presentation/widgets/common/avatar_frame.dart`.

## Hiện trạng
Cả 2 widget hiện thuần hiển thị, không có `onTap` — game muốn cho phép "tap vào 1 dòng leaderboard để xem hồ sơ người chơi" hoặc "tap avatar để đổi ảnh đại diện" phải tự bọc thêm `GestureDetector`/`PressableScale` bên ngoài, phá vỡ style tương tác nhất quán (không dùng chung `PressableScale` như mọi widget tương tác khác trong kit).

## Vì sao cần / Hậu quả
Hạn chế tái sử dụng cho 2 tương tác rất phổ biến trong casual game (xem profile đối thủ, đổi avatar).

## Đề xuất
Thêm `VoidCallback? onTap` cho cả 2 — khi non-null, bọc trong `PressableScale` (đúng primitive tương tác chung của kit) và thêm `Semantics(button: true)`.

## Acceptance criteria
- [ ] onTap khi truyền bọc đúng PressableScale, khi null giữ nguyên hành vi hiển thị thuần hiện tại.
- [ ] Test: tap khi onTap != null gọi đúng callback; tap khi onTap == null không throw và không có hiệu ứng nhấn.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-46-add-ontap-to-display-only-widgets.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API ergonomics, effort thấp, gộp 2 widget vào 1 task vì cùng 1 loại thay đổi đơn giản (thêm onTap + PressableScale).
