# X3 — Accessibility semantics cơ bản

**Epic:** Floor/UX · **SP:** 5 · **Pri:** Should · **Deps:** none

## Mục tiêu
Thêm `Semantics`/`semanticLabel` cho các widget tương tác chính (nút, booster,
tile board) để screen reader đọc được, không đổi hành vi/giao diện.

## Vì sao
Gap floor — hiện không có nhãn accessibility nào, ảnh hưởng người dùng
TalkBack/VoiceOver.

## Acceptance criteria
- [x] `neon_button.dart`: `semanticLabel` truyền qua constructor, mặc định
      dùng text hiển thị nếu không truyền riêng.
- [x] Nút booster (bomb/shuffle/undo) trong game screen: label mô tả rõ hành
      động + số lượng còn lại.
- [x] Board Flame (`GameWidget`): không bắt buộc semantics từng ô (chi phí
      cao), nhưng đảm bảo `GameWidget` không chặn semantics tree phía trên nó.
- [ ] Manual check: bật TalkBack/VoiceOver, xác nhận đọc được tên các nút
      chính (home, level, shop, settings, booster). (chưa chạy tay trên
      device, chỉ verify code + test tự động)

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `NeonButton` nhận `semanticLabel` qua constructor, mặc định
fallback về `label` hiển thị (`neon_button.dart:13,22,31,34`); nút booster ở
`game_screen.dart:544` bọc `Semantics` với label mô tả hành động + số lượng;
`home_screen.dart`/`shop_screen.dart` có nhiều `semanticLabel` trên các nút
chính (Time Attack, Zen, Daily Challenge, Spin, Perks, v.v.). `GameWidget`
không có wrapper `ExcludeSemantics`/`BlockSemantics` nào bọc quanh nó nên
không chặn semantics tree phía trên. Manual TalkBack/VoiceOver check giữ
nguyên chưa tick — cần device thật.

## Subtasks (gợi ý file)
1. `lib/presentation/widgets/neon_button.dart`: thêm `semanticLabel`.
2. `lib/presentation/screens/game_screen.dart`: label cho nút booster.
3. Rà soát nhanh các nút chính ở `home_screen.dart`, `shop_screen.dart`.

## Ghi chú kỹ thuật
Không làm semantics chi tiết cho từng ô board (200 level x nhiều ô — chi phí
không tương xứng lợi ích), chỉ tập trung UI điều khiển chính.

DoD chung: `../README.md`.
