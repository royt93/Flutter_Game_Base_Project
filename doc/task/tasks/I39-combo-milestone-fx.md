# I39 — Combo Milestone FX

**Epic:** Cảm giác/A-V · **SP:** 3 · **Pri:** Should · **Deps:** không

## Mục tiêu
Khi `GameController.comboCount` chạm các mốc cố định (ví dụ 5, 10, 15+), phát
1 hiệu ứng thị giác ngắn khác biệt theo mốc (flash màu mạnh hơn, text "COMBO
x10!" bay lên, rung haptic mạnh hơn) — hiện tại combo chỉ đổi
`comboMultiplier`/`AudioManager.applyComboLayer` (nhạc nền, `I12`) mà không
có phản hồi thị giác rõ rệt theo từng mốc.

## Vì sao
`G2-pop-trail-flash`/`G6-combo-heat` đã có phản hồi liên tục theo combo,
nhưng không có khoảnh khắc "ăn mừng" rõ rệt tại các mốc tròn — thứ tạo cảm
giác thành tựu tức thời (giống combo-text kinh điển trong game xếp hình).
Chi phí thấp: chỉ thêm 1 lớp overlay text/particle tại đúng các điểm
`comboCount` đã tăng, tái dùng hạ tầng particle/animation đã có.

## Acceptance criteria
- [ ] `lib/data/combo_milestones.dart` (mới, nhỏ): `const List<int> kComboMilestones = [5, 10, 15, 20]`
      (hoặc tương tự) — hàm pure `bool isComboMilestone(int comboCount)` =>
      `kComboMilestones.contains(comboCount)`.
- [ ] `PopStarGame`/`GameController.registerPop`: sau khi `comboCount.value++`,
      nếu `isComboMilestone(comboCount.value)` thì trigger 1 event (ví dụ
      `Rx<int?> comboMilestoneEvent` tăng dần hoặc emit qua callback) để
      `GameScreen` lắng nghe và hiện overlay text "COMBO xN!" bay lên + fade,
      kèm 1 flash màu ngắn (tái dùng cơ chế flash đã có ở `G2`, không viết
      painter mới nếu có thể chỉnh tham số cường độ theo mốc).
- [ ] Tôn trọng `reduce_motion` (`StorageKeys.reduceMotion`) — nếu bật, bỏ
      qua animation bay lên (hiện tĩnh hoặc bỏ hẳn hiệu ứng phụ, chỉ giữ
      haptic nếu haptics riêng vẫn bật) theo đúng pattern đã áp dụng ở
      `pop_star_game.dart` (`_reduceMotion` getter, `_maybeTriggerPunch`/
      `_maybeTriggerShake`).
- [ ] Haptic: nếu `StorageKeys.hapticsEnabled` bật, mốc combo cao hơn dùng
      `HapticFeedback` mạnh hơn (ví dụ mốc 5 = `lightImpact`, mốc 15+ =
      `heavyImpact`) — tái dùng import haptics đã có trong project (kiểm tra
      `I11-haptic-feedback.md` đã implement chỗ nào để nối vào đúng điểm).
- [ ] Reset: khi combo bị ngắt (`comboCount.value = 0` tại điểm reset hiện
      có trong `game_controller.dart`), không trigger FX (chỉ trigger khi
      tăng và chạm mốc, không phải khi giảm/reset).
- [ ] i18n: không cần key mới nếu overlay chỉ hiện số (không cần dịch số),
      nhưng nếu có text kèm (vd nhãn "COMBO"), thêm đủ 22 locale.
- [ ] Test: `isComboMilestone` đúng cho các giá trị trong/ngoài danh sách
      mốc. Test `GameController`/`PopStarGame`: combo tăng dần qua đúng các
      mốc trigger đúng số lần (không trigger 2 lần cho cùng 1 mốc nếu
      `registerPop` gọi nhiều lần liên tiếp mà comboCount không đổi mốc);
      reduce-motion bật → không có animation event nhưng haptic vẫn hoạt
      động độc lập (2 flag riêng, không phụ thuộc nhau).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `comboCount` (`RxInt`, `game_controller.dart:105`) tăng tại `registerPop`
  (dòng ~770), reset về 0 tại điểm timeout combo (dòng ~793) — 2 điểm chốt
  duy nhất cần đọc để không bỏ sót nhánh nào.
- Tránh nhầm với `AudioManager.applyComboLayer` (`I12`, chỉ đổi nhạc nền) —
  `I39` là lớp visual/haptic hoàn toàn tách biệt, không đụng audio layer.

DoD chung: `../README.md`.
