---
id: IDEA-60
title: "Directional screen shake theo vector va chạm Flame — ScreenShake hiện tại có hướng ngẫu nhiên/đồng đều"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
`lib/presentation/widgets/common/screen_shake.dart` (mở rộng), tích hợp với Flame collision callback.

## Hiện trạng
`ScreenShake` hiện có hiệu ứng rung màn hình chung, không nhận vector hướng va chạm để làm rung có định hướng (ví dụ va chạm từ bên trái làm màn hình rung lệch phải mạnh hơn).

## Vì sao cần / Hậu quả
Game-feel/juice tốt hơn cho các va chạm Flame — cảm giác phản hồi vật lý rõ ràng hơn shake đồng đều ngẫu nhiên.

## Đề xuất
Thêm tham số `direction: Vector2?` optional cho `ScreenShake` — khi có, thiên vị biên độ rung theo hướng đó; khi không có (mặc định), giữ hành vi ngẫu nhiên đồng đều như hiện tại.

## Acceptance criteria
- [ ] `ScreenShake(direction: ...)` rung có thiên hướng đúng theo vector truyền vào.
- [ ] `ScreenShake()` không truyền `direction` giữ nguyên hành vi cũ.
- [ ] Test widget verify offset rung thiên đúng hướng khi có `direction`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-60-directional-screen-shake-flame-collision.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/screen_shake.dart` và test hiện có trước khi thêm tham số mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (cảm nhận trực quan hiệu ứng juice) không bắt buộc nếu widget test đủ chứng minh offset đúng.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng game-feel hợp lý, giá trị thấp/vừa, không phải bug. Không trùng task nào trong `doc/task/done/`.
