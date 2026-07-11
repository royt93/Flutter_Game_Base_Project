# F8 — Mode Time-attack + Zen

**Epic:** Features · **SP:** 8 · **Pri:** Could · **Deps:** — (side mode, tách khỏi campaign)

## Mục tiêu
Hai mode phụ vào từ Home:
- **Time-attack**: 60s, nổ càng nhiều điểm càng tốt, lưu best score.
- **Zen**: bàn tự đầy lại nhẹ nhàng, không thua, không đếm giờ — thư giãn.

## Vì sao
Đa dạng lối chơi, tăng thời lượng; Zen phục vụ người chơi casual muốn "chill".

## Acceptance criteria
- [ ] Home có lối vào 2 mode (ngoài PLAY campaign).
- [ ] Time-attack: đồng hồ đếm ngược 60s; hết giờ → dialog best score; KHÔNG đụng
  win-streak/unlock/coin campaign (side mode nguyên tắc: không chạm meta campaign).
- [ ] Zen: không thua/không target; có nút thoát; (tùy chọn) refill nhẹ để chơi lâu.
- [ ] Lưu best score Time-attack (storage). Widget test smoke mỗi mode.

## Subtasks (gợi ý file)
1. `lib/presentation/controllers/game_controller.dart`: cờ mode (`GameMode` enum:
   campaign/timeAttack/zen); `checkEnd`/scoring rẽ nhánh theo mode; side mode KHÔNG
   ghi unlock/coin campaign.
2. `lib/game/pop_star_game.dart`: Zen cần refill (tùy chọn) — khác luật "no refill"
   campaign; thêm cờ `refill`.
3. Time-attack: TimerComponent 60s → controller.checkEnd.
4. UI: nút Home + dialog kết quả riêng.
5. Test: `test/presentation/modes_test.dart`.

## Ghi chú kỹ thuật
Giữ nguyên tắc side-mode: tuyệt đối không đụng `unlockedLevel`/coin-campaign/star.
Zen refill là ngoại lệ luật no-refill — cô lập bằng cờ, đừng đổi campaign.

DoD chung: `../README.md`.
