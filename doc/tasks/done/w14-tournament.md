---
id: w14-tournament
title: Event — Tournament / Thách đấu tuần
wave: 14
status: done
owner: claude
---

# Tournament — giải đấu tuần (offline)

Giải theo tuần (như Season dùng epoch-week): tích điểm giải từ thắng màn/endless/
daily; bảng xếp hạng OFFLINE (người chơi + bot AI có tên/điểm mô phỏng) để tạo
cảm giác đua hạng; cuối tuần thưởng theo hạng. Chống chỉnh giờ qua `_effectiveDay`.

Thiết kế offline thuần (không backend): đối thủ là bot điểm sinh tất định theo
tuần (seed = weekIndex) leo dần theo ngày → người chơi thấy mình tụt/lên hạng.

## Việc
- `lib/data/tournament.dart` (tên bot + thưởng theo hạng + mốc tuần).
- `TournamentController` (permanent, resetState, maybe): điểm tuần, leaderboard
  tính tất định, thưởng cuối tuần (claim 1 lần/tuần).
- `TournamentScreen` (bảng xếp hạng + thưởng + đếm ngược tuần). Nút Home.
- addScore(stars/points) gọi từ GameScreenController. i18n en+vi.

## Test
- điểm tuần cộng; leaderboard tất định theo seed tuần; hạng đúng; thưởng 1 lần/tuần;
  đổi tuần reset; persist + reset.
