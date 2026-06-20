---
id: w17-2-labyrinth-moving-walls-fog
title: Mê cung → tường động + sương mù
wave: 17
phase: 2
status: todo
owner: claude
---

# Phase 2 — Mê cung: tường DI ĐỘNG + sương mù (hết reskin DropDown)

## Vấn đề hiện tại (audit)
Mê cung = DropDown + 1 layout tường tĩnh (`kLabyrinthMap`). Cơ chế "qua mê cung" =
engine settle/trượt-chéo CÓ SẴN cho mọi board có layout (campaign 103/127 cũng dùng).
**Engine không đọc `isLabyrinth`** → khác biệt = 1 file layout.

## Thiết kế mới — 2 lớp cơ chế riêng
1. **Tường DI ĐỘNG**: sau mỗi `kMazeShiftMoves` lượt (vd 5), 1 đoạn tường dịch
   chuyển (mở khe mới / đóng khe cũ) → mê cung "sống", buộc đổi kế hoạch đưa gem xuống.
2. **Sương mù (fog-of-war)**: các ô cách đích > `kFogRadius` bị che (render mờ + không
   hint match) cho tới khi gem mục tiêu tiến gần → cảm giác khám phá.
3. Mục tiêu giữ: đưa K tinh thể xuống đáy (dropDown) NHƯNG qua mê cung biến đổi.

## Triển khai
- `lib/data/levels.dart`: bộ layout mê cung riêng cho Labyrinth (khác campaign), +
  định nghĩa "kịch bản dịch tường" (danh sách (lượt → layout mới)).
- Engine `neon_jewel_game.dart`: nhánh ĐỌC `controller.isLabyrinth`:
  - `_mazeShiftTimer` theo lượt → `_applyLayoutOverride(newLayout)` (tái dùng
    `_buildLayout`/`layoutOverride` của W15) + settle lại an toàn.
  - lớp fog: `FogLayer` (PositionComponent phủ ô xa đích) — chỉ render, không đổi logic.
- `game_controller_modes.dart`/`scoring.dart`: nhánh `isLabyrinth` đã có (giữ điều kiện
  thắng dropDown), thêm trạng thái maze-shift index.
- Const: `kMazeShiftMoves`, `kFogRadius`, danh sách bố cục dịch.

## Test (unit + widget) — WINNABILITY là trọng tâm
- ⚠️ Bài học W15: mê cung tường giữa hàng mở làm gem KẸT → BẮT BUỘC test descent-sim
  cho MỌI trạng thái tường (trước & sau mỗi shift): gem mục tiêu luôn có đường xuống đáy.
- `_applyLayoutOverride` không xoá/kẹt gem; settle lại fill đầy + `hasPossibleMove`.
- Fog chỉ ảnh hưởng render (logic match không đổi).
- ISOLATION side-mode.

## Lưu ý
- Tái dùng engine layout/flow/settle của W15 (đã có `layoutOverride`, `_buildLayout`,
  `settleBoardFlow`). Chỉ thêm "đổi layout giữa ván" + fog overlay.
- Mỗi trạng thái tường phải pass winnability-sim TRƯỚC khi ship (như test Labyrinth W15).
- Liên quan: [[w15-layout-architecture]], [[side-mode-isolation]].
