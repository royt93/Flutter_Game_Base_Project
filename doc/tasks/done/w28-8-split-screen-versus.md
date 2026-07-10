---
id: w28-8-split-screen-versus
title: "Local Split-Screen Realtime Versus"
wave: 28
phase: 8
status: done
owner: claude
---

# Phase 8 — Local Split-Screen Realtime Versus

## Kết quả (phát hiện lúc verify Wave 28.1, `.claude/plans/fuzzy-mapping-shannon.md`)

Đã implement thật — không phải làm mới. `lib/presentation/screens/versus_screen.dart`
`_buildPlaying()` dựng 2 `GameWidget` độc lập từ `c.game1`/`c.game2` (2 `FlameGame`
instance riêng), xếp `Column` dọc, người trên (`_playerPane(c, 2, ...)`) xoay 180°
qua `RotatedBox`. Đúng concept "2 bàn Flame riêng biệt cùng lúc trên 1 màn hình,
2 người thao tác đồng thời" nêu dưới đây. Không cần làm thêm; giữ mục "Rủi ro" bên
dưới làm checklist nếu sau này cần tối ưu performance/input trên máy yếu.

## Concept

Nâng cấp Versus (Wave 8.7) từ "1 bàn, 2 người thay lượt so điểm" thành 2 bàn Flame
riêng biệt cùng lúc trên 1 màn hình — 2 người chơi thao tác đồng thời, thấy bàn
đối phương realtime. Khác với `w28-4` (ghost PvP async) — đây là local realtime,
không cần lưu replay.

## Phạm vi đề xuất

1. Chia màn hình ngang/dọc (tuỳ orientation) — mỗi nửa 1 `FlameGame` instance độc
   lập (board nhỏ hơn, VD 6×6 thay 7×7 hiện tại để vừa nửa màn).
2. Input tách vùng: gesture detector mỗi bàn chỉ nhận input trong vùng của mình
   (tránh 1 tay chạm nhầm bàn kia trên màn nhỏ).
3. Đồng hồ chung quyết thắng thua (giữ nguyên từ Versus cũ) — chỉ đổi UI/board
   layout, không đổi rule thắng thua.

## Rủi ro cần lưu ý

- **Phức tạp kỹ thuật cao nhất** trong 4 idea: 2 `FlameGame` chạy đồng thời có thể
  ảnh hưởng performance (đặc biệt máy yếu) — cần test frame rate kỹ trên máy
  low-end trước khi merge.
- Input tranh chấp trên màn hình nhỏ (điện thoại) — cần test tay thật, không chỉ
  test logic, để xác nhận 2 vùng chạm không đè nhau.
- Vì đây là local 2-người-1-máy, target chính là tablet/màn lớn — cần xác nhận
  UX trên điện thoại nhỏ có chấp nhận được không trước khi đầu tư đầy đủ.

## Việc cần làm khi bắt đầu

- [ ] Đọc kỹ `neon_jewel_game.dart` cấu trúc `FlameGame` hiện tại trước khi nhân đôi instance.
- [ ] Prototype nhỏ đo frame rate 2 board đồng thời trên máy low-end trước khi làm đầy đủ.
- [ ] Test tay thật input 2 vùng không đè nhau.
- [ ] Verify máy thật (điện thoại thường + máy yếu) trước khi đánh dấu done.
