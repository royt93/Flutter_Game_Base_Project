# F13 — Daily Challenge

**Epic:** Features · **SP:** 8 · **Pri:** Should · **Deps:** I7 (chung khái niệm 1-lần/ngày), I9 (nối leaderboard)

## Mục tiêu
1 bàn cố định mỗi ngày — seed theo ngày (`Random(seed)`, không `Random()` mặc
định) để mọi người chơi cùng ngày gặp cùng bàn, so điểm với leaderboard bạn bè
giả lập (I9).

## Vì sao
Cầu nối tự nhiên giữa mode mới và leaderboard — seed-theo-ngày giữ
deterministic, dễ test, không cần backend.

## Acceptance criteria
- [ ] Hàm sinh board từ seed = ngày hiện tại (`Random(seed)` có seed, không
      `Random()` mặc định).
- [ ] 1 lượt tính điểm/ngày (check giống `claimDaily`); chơi lại trong ngày
      không ghi điểm mới.
- [ ] Kết quả ngày lưu vào danh sách rank giả lập (I9) nếu đã có, không thì chỉ
      lưu điểm ngày riêng.
- [ ] Unit test: cùng ngày → cùng seed → cùng board (2 lần sinh giống hệt).

## Subtasks (gợi ý file)
1. `lib/logic/` hoặc `lib/data/`: hàm sinh board seed = ngày.
2. `lib/presentation/controllers/game_controller.dart`: `dailyChallengeScore`,
   trạng thái đã chơi hôm nay.
3. UI entry point (home hoặc level_select).

## Ghi chú kỹ thuật
`Random(seed)` với `seed = year*10000+month*100+day` là đủ, không cần thuật
toán phức tạp.

DoD chung: `../README.md`.
