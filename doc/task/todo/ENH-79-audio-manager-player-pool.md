---
id: ENH-79
title: "AudioManager tạo mới 1 AudioPlayer cho mỗi playSfx() — cần pool tái sử dụng cho combo SFX dồn dập"
type: enhancement
priority: P1
effort: M
source: "agy (độc lập), verify lại qua Read lib/core/audio_manager.dart (khu vực playSfx)"
---

## Vị trí
`lib/core/audio_manager.dart` — `playSfx()` (~dòng 168-171).

## Hiện trạng
Mỗi lần gọi `playSfx()` tạo mới 1 `AudioPlayer` (`audioplayers` package) — không tái sử dụng.

## Vì sao cần / Hậu quả
Khi combo kẹo/hiệu ứng liên tiếp bắn 15-20 SFX/giây (đặc trưng casual match-3/idle game), việc mở 15-20 native audio channel đồng thời có thể nghẽn audio driver trên Android cấp thấp — SFX bị trễ, rè, hoặc rớt tiếng.

## Đề xuất
Thêm 1 pool nội bộ (4-6 `AudioPlayer` tái sử dụng, round-robin hoặc theo trạng thái rảnh/bận) — `playSfx()` mượn 1 player rảnh trong pool thay vì luôn tạo mới; player được release lại pool khi phát xong.

## Acceptance criteria
- [ ] Gọi `playSfx()` liên tiếp (ví dụ 20 lần trong 1 giây) không tạo quá N (cấu hình được, mặc định 4-6) instance `AudioPlayer` đồng thời.
- [ ] SFX vẫn phát đúng âm thanh yêu cầu, không bị cắt ngang bởi player khác đang dùng chung slot pool (nếu pool hết chỗ, có chính sách rõ ràng: chờ/bỏ qua/ngắt SFX cũ nhất — ghi rõ trong code).
- [ ] Hành vi `AudioManager.maybe`/mute/API công khai khác không đổi.
- [ ] Test verify số lượng `AudioPlayer` instance được tạo không vượt pool size khi gọi `playSfx` dồn dập.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-79-audio-manager-player-pool.md` này trước khi làm. Đọc toàn bộ `lib/core/audio_manager.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android cấp thấp (nếu có sẵn) khuyến khích để nghe thử combo SFX dồn dập không còn rè/trễ; không bắt buộc nếu chỉ có thiết bị cao cấp sẵn có.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — hành vi "mỗi lần gọi tạo mới AudioPlayer" là pattern dễ kiểm chứng qua đọc code; chưa tự Read lại đúng dòng do khối lượng batch verify. Không trùng task nào trong `doc/task/done/`.
