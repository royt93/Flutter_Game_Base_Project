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
- [x] Node `unlocked` có motion thu hút mắt, tắt đúng khi `reducedMotion`.
- [x] Node `completed` dùng `glow()` (hoặc `glow()` + `drop()`), test golden cập nhật nếu cần.

## Ghi chú độ tin cậy
Thấp-trung bình — cải thiện thẩm mỹ chủ quan, không phải thiếu sót rõ
ràng. Cân nhắc: thêm ticker liên tục cho MỌI node unlocked trên 1 lưới
nhiều ô có thể tốn hiệu năng hơn đáng kể so với 1 node đơn lẻ — nên giới
hạn chỉ node unlocked ĐẦU TIÊN (level tiếp theo thật sự), không phải mọi
node unlocked nếu có nhiều.

## Quyết định
Làm đúng cả 2 đề xuất. `LevelNodeButton` chuyển từ `StatelessWidget` sang
`StatefulWidget` (`SingleTickerProviderStateMixin`), thêm field `pulse`
(mặc định `false`, caller quyết định — widget không tự suy luận "mình có
phải node đầu tiên không"). Khi `pulse && state == unlocked &&
!reducedMotion`, 1 `AnimationController` chạy `repeat(reverse: true)` chu
kỳ 900ms (fade 0.35↔1.0 qua `Curves.easeInOut`), dùng giá trị đó làm
`intensity` cho `NeonTheme.glow(NeonTheme.cyan, blur: 16, intensity:
...)` cộng thêm `drop()` gốc. `LevelSelectGrid.build()` tính
`states.indexOf(LevelState.unlocked)` và chỉ set `pulse: true` cho đúng 1
node đó — đúng như lưu ý về hiệu năng, không chạy ticker cho mọi node
unlocked.

Node `completed`: `boxShadow` đổi từ chỉ `NeonTheme.drop(y: 3, blur: 8)`
thành `[...drop(...), ...NeonTheme.glow(NeonTheme.gold, blur: 14)]` — cộng
cả 2 (không thay thế hẳn) để giữ độ "chunky" của drop shadow đồng thời
thêm glow nhất quán với phần còn lại của kit.

Đọc `NeonTheme.reducedMotion(context)` trong `didChangeDependencies()`
(không phải `initState()`) — cùng convention đã lập ở ConfettiOverlay/
RibbonBadge trong session này. `_syncTicker()` gọi cả ở
`didChangeDependencies` (lần đầu) và `didUpdateWidget` (khi `pulse`/`state`
đổi qua lại, ví dụ node đang pulse vừa được chơi xong → chuyển sang
completed → tự dừng ticker).

Không có golden test nào cho widget này (chỉ có
`test/widget/common/level_select_grid_test.dart`, không phải golden) nên
không cần regenerate ảnh.

Test: 5 test mới (root) — completed dùng glow+drop, unlocked không pulse
chỉ có drop tĩnh, unlocked+pulse glow dao động theo thời gian (so 2 mốc
thời gian, alpha khác nhau), pulse=true nhưng state=completed thì bỏ qua
pulse, và reducedMotion tắt hẳn animation. `flutter analyze` sạch cả root
+ `example/`. `flutter test --exclude-tags slow`: tất cả pass, không
regression (483→488).

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Level Select, glow cyan quanh node 4 (unlocked, level tiếp theo) và glow
gold quanh node 1-3 (completed) thấy rõ qua screenshot — so với trước hoàn
toàn phẳng. Chụp 2 screenshot liên tiếp cho thấy độ đậm glow ở node 4 hơi
khác nhau (dấu hiệu animation đang chạy, dù không đủ rõ để khẳng định
chắc chắn qua ảnh tĩnh — bằng chứng chính vẫn là test đơn vị). Không
exception trong logcat.
