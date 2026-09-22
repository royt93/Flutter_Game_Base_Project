---
id: IDEA-67
title: "AudioHapticSync — đồng bộ nhịp điệu HapticChoreographer theo âm thanh SFX thực tế"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mới, dựa trên `lib/core/haptic_choreographer.dart` (`HapticPattern`) và `lib/core/audio_manager.dart`.

## Hiện trạng
`HapticChoreographer` sequences 1 `HapticPattern` (pulse có delay riêng) độc lập với `AudioManager` — không có cơ chế đồng bộ 2 bên (ví dụ combo SFX pitch-escalation + haptic pulse cùng nhịp).

## Vì sao cần / Hậu quả
Cảm giác phản hồi tốt hơn khi haptic và âm thanh đồng bộ nhịp điệu — đặc biệt hữu ích nếu kết hợp với ý tưởng "Dynamic Audio Pitch Escalation cho Combo" (đã cân nhắc nhưng KHÔNG đưa vào backlog lần này, xem ghi chú trong BACKLOG-AUDIT).

## Đề xuất
Thêm 1 helper nhỏ nhận `HapticPattern` + số bước combo, tự tính delay pulse tương ứng đồng bộ với 1 SFX đang phát (không cần audio-analysis phức tạp — chỉ cần đồng bộ timing đã biết trước, ví dụ combo step N ứng với pulse thứ N).

## Acceptance criteria
- [ ] Helper tạo đúng `HapticPattern` đồng bộ theo số bước combo truyền vào.
- [ ] Không đổi hành vi `HapticChoreographer`/`AudioManager` hiện có khi không dùng helper mới.
- [ ] Test unit cho helper.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-67-audio-haptic-pattern-sync.md` này trước khi làm. Đọc toàn bộ `lib/core/haptic_choreographer.dart` và `lib/core/audio_manager.dart` trước khi implement. Implement bằng TDD, ưu tiên giải pháp tối giản (ponytail) — không cần audio-analysis thời gian thực, chỉ cần đồng bộ timing đã biết trước.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (cảm nhận trực quan haptic+audio đồng bộ) không bắt buộc nếu unit test đủ chứng minh timing logic.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng game-feel hợp lý dựa trên 2 hạ tầng đã có thật, giá trị thấp/vừa. Không trùng task nào trong `doc/task/done/`.
