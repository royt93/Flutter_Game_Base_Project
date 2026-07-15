# I9 — Leaderboard bạn bè (offline giả lập)

**Epic:** Meta/retention · **SP:** 8 · **Pri:** Could · **Deps:** none (offline, không cần backend)

## Mục tiêu
Bảng xếp hạng cục bộ — so điểm cao nhất/tổng sao với vài "bot ảo" tên cố định
(giả lập, không backend thật).

## Vì sao
User muốn leaderboard bạn bè nhưng không có backend — bản offline giả lập vẫn
tạo cảm giác cạnh tranh mà không tăng infra (đã loại ở Option D).

## Acceptance criteria
- [x] Danh sách bot ảo cố định (tên + điểm mốc tăng dần theo world) trong data.
- [x] Màn hình leaderboard hiện vị trí người chơi (theo tổng sao/điểm cao nhất)
      chen giữa bot ảo.
- [x] KHÔNG gọi network/backend nào — giữ đúng scope offline.
- [x] Unit test: tính đúng vị trí xếp hạng khi chèn điểm người chơi vào danh
      sách bot.

## Rà soát checkbox (2026-07-13)
- `lib/data/leaderboard_bots.dart` (danh sách bot tĩnh), `lib/logic/leaderboard.dart`
  (`buildLeaderboard`/`playerRank` thuần), `lib/presentation/screens/leaderboard_screen.dart`.
- Grep `http|dio|socket|Socket` trong cả 3 file: không có match — xác nhận offline thuần.
- `test/logic/leaderboard_test.dart` test chèn đúng vị trí + tie-break.

## Subtasks (gợi ý file)
1. `lib/data/` — danh sách bot tĩnh.
2. Hàm tính rank thuần (`lib/logic/` hoặc `core/`).
3. Màn hình mới hoặc tab trong home.

## Ghi chú kỹ thuật
Đặt tên rõ "giả lập offline" trong comment/doc để không ai tưởng nhầm có backend
thật — nền tảng để nối bạn bè thật sau này nếu có infra.

DoD chung: `../README.md`.
