# I41 — Mascot Reaction theo Combo Streak

**Epic:** Cảm giác/A-V · **SP:** 3 · **Pri:** Could · **Deps:** không

## Mục tiêu
`StarMascot` (`lib/presentation/widgets/star_mascot.dart`) hiện chỉ có 2
trạng thái mood dùng trong game (`cheer` khi `comboMultiplier > 1.4`, `idle`
khi không) — mở rộng ánh xạ combo chi tiết hơn theo `comboCount` thực tế
(không chỉ hệ số nhân) để mascot phản ứng rõ rệt hơn: `idle` (combo 0-1),
`happy` (combo 2-4, mood có sẵn nhưng chưa dùng ở game screen), `cheer`
(combo ≥5).

## Vì sao
`StarMood` enum (`idle, happy, sad, cheer`) đã tồn tại đủ 4 trạng thái nhưng
`game_screen.dart` chỉ dùng nhị phân `cheer`/`idle` theo `comboMultiplier`,
bỏ phí trạng thái `happy` đã có sẵn animation riêng. Đây là thay đổi 1 dòng
điều kiện nhưng tăng đáng kể độ "sống" của mascot trong lúc chơi, chi phí gần
như bằng 0 vì animation `happy` đã được implement.

## Acceptance criteria
- [ ] `game_screen.dart` (khoảng dòng 331-333, nơi đang set
      `mood: gameCtrl.comboMultiplier.value > 1.4 ? StarMood.cheer : StarMood.idle`):
      đổi sang ánh xạ theo `gameCtrl.comboCount.value` (không phải
      `comboMultiplier`, chính xác hơn vì là số nguyên trực tiếp): `0-1 →
      idle`, `2-4 → happy`, `≥5 → cheer`. Có thể tách thành 1 hàm nhỏ
      `StarMood moodForCombo(int comboCount)` (pure, không cần file riêng —
      đặt ngay trong `game_screen.dart` hoặc `star_mascot.dart` nếu muốn test
      độc lập).
- [ ] Không đổi 2 chỗ dùng mood khác trong `game_screen.dart` (dòng ~691
      `isTimeAttack ? cheer : sad` cho màn kết quả, dòng ~801 `cheer` cố định
      cho 1 trường hợp khác) — chỉ sửa đúng điểm mood-trong-lúc-chơi theo
      combo.
- [ ] Tôn trọng `reduce_motion`: `StarMascot` cần xác nhận animation
      chuyển mood (nếu có transition) vẫn tắt lặp vô hạn khi
      `StorageKeys.reduceMotion` bật (đã có từ fix trước, `commit 28ccb94`) —
      không cần sửa gì thêm nếu cơ chế đó đã áp dụng đúng cho mọi `mood`,
      chỉ cần xác nhận bằng test không có animation nào trôi vô hạn (giữ
      nguyên hành vi, không phải yêu cầu code mới).
- [ ] i18n: không cần (không có text mới).
- [ ] Test: `moodForCombo` (nếu tách hàm riêng) — đúng 3 khoảng giá trị biên
      (0, 1, 2, 4, 5, số lớn). Widget test: `GameScreen`/component chứa
      mascot hiện đúng mood tương ứng khi `comboCount` thay đổi qua các mốc
      biên (2, 4, 5) trong lúc chơi.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Đây là task nhỏ nhất trong đợt — chủ yếu đổi điều kiện đã có sẵn animation
  hậu thuẫn (`happy` mood), rủi ro thấp, không đụng logic gameplay/pure logic
  nào.
- Có thể làm song song/độc lập với `I39` (Combo Milestone FX) — 2 task khác
  nhau: I39 là hiệu ứng one-shot tại mốc, I41 là trạng thái liên tục theo
  combo hiện tại.

DoD chung: `../README.md`.
