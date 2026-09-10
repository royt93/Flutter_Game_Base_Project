---
id: IDEA-25
title: "LevelSelectGrid: node đang mở (unlocked) không có hiệu ứng thu hút mắt, node completed dùng drop shadow thay vì glow"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork D)
---

## Ý tưởng
`LevelNodeButton` (`lib/presentation/widgets/common/level_select_grid.dart`)
render 3 trạng thái tĩnh hoàn toàn (locked/unlocked/completed) — không node
nào có bất kỳ motion liên tục nào. Trong đó:
1. Node `unlocked` (level tiếp theo người chơi SẼ chơi) trông y hệt hình
   dạng của node `completed` (chỉ khác màu), không có gì "mời gọi" người
   chơi bấm vào — nhiều casual game pulse/glow nhẹ đúng node này để dẫn mắt.
2. Node `completed` (gold) chỉ có `NeonTheme.drop(y: 3, blur: 8)` (bóng đổ
   thường) chứ không phải `NeonTheme.glow(...)` — trong khi `AvatarFrame`/
   `CountdownChip` và nhiều widget khác dùng `glow()` cho viền màu accent,
   khiến node gold ở đây trông "phẳng" hơn mong đợi so với phần còn lại
   của kit.

## Vì sao cần
`LevelSelectGrid` là màn hình người chơi nhìn thấy thường xuyên nhất
(world map/level select) — thêm 1 chút motion có mục đích (pulse nhẹ ở
node đang mở) và glow nhất quán ở node hoàn thành sẽ nâng cảm giác "cao
cấp" đáng kể mà không cần đổi cấu trúc.

## Đề xuất
- Node `unlocked`: thêm 1 pulse glow nhẹ liên tục (opacity/scale dao động
  chậm, ~1.5-2s chu kỳ) — tôn trọng `NeonTheme.reducedMotion` (tắt hẳn
  ticker khi bật, giống pattern `NeonBg`/`ShimmerPlaceholder`).
- Node `completed`: đổi `boxShadow: NeonTheme.drop(...)` thành
  `NeonTheme.glow(NeonTheme.gold, ...)` (hoặc cộng thêm cả 2) cho nhất
  quán với các widget khác dùng glow cho accent màu.

## Acceptance criteria
- [ ] Node `unlocked` có motion thu hút mắt, tắt đúng khi `reducedMotion`.
- [ ] Node `completed` dùng `glow()` (hoặc `glow()` + `drop()`), test golden cập nhật nếu cần.

## Ghi chú độ tin cậy
Thấp-trung bình — cải thiện thẩm mỹ chủ quan, không phải thiếu sót rõ
ràng. Cân nhắc: thêm ticker liên tục cho MỌI node unlocked trên 1 lưới
nhiều ô có thể tốn hiệu năng hơn đáng kể so với 1 node đơn lẻ — nên giới
hạn chỉ node unlocked ĐẦU TIÊN (level tiếp theo thật sự), không phải mọi
node unlocked nếu có nhiều.
