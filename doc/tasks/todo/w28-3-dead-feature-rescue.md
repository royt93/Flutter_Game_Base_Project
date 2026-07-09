---
id: w28-3-dead-feature-rescue
title: "Cứu dead-feature risk: Piggy/Collection/Progression Tree/Lucky Wheel"
wave: 28
phase: 3
status: todo
owner: claude
---

# Phase 3 — Cứu "dead feature" risk

## Vì sao (audit)

- **Piggy Bank** (`piggy_controller.dart`): coin-sink pure, thưởng = bỏ tiền vào ống
  rồi lấy lại chính số đó (cap 600) — không tạo giá trị mới, người chơi không thấy
  lý do quan tâm.
- **Collection** (`collection_controller.dart`): chỉ 1 reward duy nhất (skin exclusive)
  khi hoàn tất 100% bộ sticker — nếu người chơi không cần skin đó, toàn bộ hệ thống
  vô nghĩa với họ.
- **Progression Tree** (`progression_tree_controller.dart`): thuần visual (particle
  burst ×1.5/2.0/2.5, prestige skin), không có gameplay hook.
- **Lucky Wheel** (`lucky_wheel_controller.dart`): RNG thuần 50/50 xu vs booster,
  không strategy, không tăng dần giá trị theo thời gian chơi.

Đối lập: **Challenge Card** là hub synergy tốt nhất (nối Battle Pass + Season +
Side-Mode Record) — dùng làm mẫu tham khảo khi thiết kế lại các hệ trên.

## Phạm vi đề xuất

1. Piggy Bank: thêm bonus khi đập (ví dụ +10% số đã gom, hoặc đổi được item khác
   ngoài coin thuần) để "đập" có cảm giác thưởng thật, không chỉ rút lại tiền đã bỏ.
2. Collection: thêm mốc thưởng giữa chừng (25%/50%/75% bộ) — xu nhỏ hoặc booster —
   không chỉ chờ 100%.
3. Progression Tree: thêm 1 hiệu ứng gameplay nhẹ ở node cao nhất (không chỉ visual)
   — ví dụ +1 lượt miễn phí mỗi ngày khi mở `ascendant`.
4. Lucky Wheel: thêm pity/streak nhẹ (n lần liên tiếp toàn "xu ít" → tăng tỉ lệ
   booster lần sau) — tái dùng khái niệm DDA pity đã có ở campaign (Wave 16.3).

## Rủi ro cần lưu ý

- Đụng nhiều economy formula → **phải** re-test `resetProgress()`/anti-exploit toàn
  bộ (xem `game_controller_progress.dart`, mục Reward Anti-Exploit trong `CLAUDE.md`).
- Phạm vi rộng hơn 5 file — không fan-out subagent riêng lẻ nếu các file này đụng
  chung `game_controller_economy.dart`.

## Việc cần làm khi bắt đầu

- [ ] Đọc kỹ 4 controller trên + `game_controller_economy.dart`.
- [ ] Thiết kế số liệu cụ thể (không đổi cap hiện có mà không tính lại cân bằng).
- [ ] Test `resetProgress()` xoá sạch cả state mới thêm (disk + RAM).
- [ ] Verify máy thật: claim/reset không nhân đôi thưởng.
