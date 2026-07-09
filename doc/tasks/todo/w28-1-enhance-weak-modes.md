---
id: w28-1-enhance-weak-modes
title: "Enhance mode yếu + mechanic phí"
wave: 28
phase: 1
status: todo
owner: claude
---

# Phase 1 — Enhance mode yếu + tận dụng mechanic có sẵn

## Vì sao (audit)

- **Versus** (`game_controller_modes.dart`): engine tái dùng 100% từ campaign, "KHÔNG
  đụng `_load`, `checkEnd→null`" → 2 người chơi chỉ so điểm trên 1 bàn, không có
  mechanic PvP thật (bomb steal, power đánh nhau). Đồng hồ ngoài quyết định thắng
  thua, game không tự biết kết thúc.
- **Puzzle** (`lib/data/puzzles.dart`): chỉ 8 cấu đố cứng, hết cấu đố 8 = khoá hoàn
  toàn. Không có hard variant / mutator giống Daily.
- **Zen**: không leaderboard riêng, không milestone ngoài high-score cá nhân
  (`zenHigh`), thưởng thoát = `(score/1000).clamp(5,50)` xu — không có lý do quay lại
  ngoài chơi thư giãn.
- **ColorRush**: 1 chiều cơ chế (màu nóng xoay mỗi 4 lượt → streak ×1..3), mục tiêu
  cụt 3500 điểm, không event/variation.
- **Gravity**: chỉ flip bàn mỗi 5 lượt (`kGravityFlipEvery`), bàn phẳng không
  layout/flow/obstacle riêng — từng có bug rơi nhánh campaign (đã fix).
- **Mechanic phí**: `settleBoardFlow`/`FlowDir` (Gravity Streams) chỉ dùng ở **1/200**
  level (115). Conveyor/Portal/Dispenser mỗi loại chỉ **2/200** level.

## Phạm vi đề xuất

1. Versus: thêm 1 mechanic PvP nhẹ (combo lớn → gửi junk-gem/rác sang bàn đối
   phương — engine junk-gem đã có từ Wave 8.8, chỉ cần wire 2 chiều thật).
2. Puzzle: thêm "hard variant" mở sau khi 3 sao cấu đố 8 (tái dùng pattern
   `hardVariant` đã có ở Side Mode Record).
3. Zen: thêm milestone thưởng theo mốc điểm (không chỉ high-score), tái dùng
   pattern `RecordOutcome`/tier đã có ở Side Mode Record.
4. ColorRush/Gravity: thêm 1-2 biến thể mutator (tái dùng Daily mutator pattern).
5. Thêm 5-8 level mới dùng Flow/Conveyor/Portal/Dispenser (world 9-10) để tăng
   tỉ lệ showcase mechanic đã build.

## Việc cần làm khi bắt đầu

- [ ] Đọc kỹ `game_controller_modes.dart`, `neon_jewel_game.dart` phần Versus/Zen/ColorRush/Gravity.
- [ ] Thiết kế cụ thể từng enhancement (tránh đụng file lõi chung nếu làm song song).
- [ ] `dart run tool/playtest.dart` re-validate nếu thêm level mới.
- [ ] Verify máy thật ít nhất 1 flow mỗi mode enhance.
