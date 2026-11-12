---
id: ENH-107
title: "Link chữ bọc GestureDetector thiếu role button và vùng chạm nhỏ (7 widget)"
type: enhancement
layer: lib/widgets/common
priority: P2
effort: M
source: "FEAT-202: rule tapTargetSite 2026-11-12; cùng lớp lỗi ENH-106 (SpotlightOverlay skip link)"
---

## Phạm vi (đọc code, mỗi dòng là một vị trí trong baseline)
Chữ `Text` bọc `GestureDetector` không có `Semantics(button: true)`, vùng chạm bằng chiều cao chữ (nhỏ hơn 48dp):
- `achievement_roadmap_card.dart:274` (Claim), `reward_track_road.dart:374` (Claim)
- `collection_album_panel.dart:171` (View Reward)
- `friend_invite_progress_card.dart:200` (copy invite), `:240` (chip mốc)
- `guild_contribution_card.dart:227` (chip mốc), `:284` (Retry)
- `level_up_overlay.dart:436` (skip)
- `crafting_recipe_card.dart:263` (chip nguyên liệu)
- `character_collection_grid.dart:343`: vùng chạm đã 48dp, chỉ thiếu `Semantics(button)`.

## Cần quyết định riêng (không phải nút)
Cử chỉ chạm-để-bỏ-qua trên nội dung: `currency_counter.dart:204`, `offline_earnings_popup.dart:244`, `reward_sequence_coordinator.dart:277`. Barrier chạm-ra-ngoài-để-đóng: `spotlight_overlay.dart:115`, `neon_dialog.dart:179/238`. Quyết định có cần `Semantics` (ví dụ thao tác "dismiss") hay không.

## Hướng sửa
Theo mẫu ENH-106: `MergeSemantics` + `Semantics(button: true)` + padding dọc đủ 48dp + `HitTestBehavior.opaque`. Thêm test chiều cao >= 48 và ancestor `Semantics(button)`. Thêm padding đổi layout nên kiểm golden: nếu đổi, regenerate bằng quy trình artifact (chỉ chép PNG đổi pixel).

## Kết quả (2026-11-12): 10 link đã sửa
`MergeSemantics` + `Semantics(button: true)` + `HitTestBehavior.opaque` + vùng chạm tối thiểu 48dp (căn giữa trong `ConstrainedBox`, giao diện chữ không đổi) cho: achievement Claim, reward_track Claim, collection View Reward, friend invite copy và chip mốc, guild chip mốc và Retry, level_up skip, crafting chip nguyên liệu. `character_collection_grid` Select chỉ thêm role (đã đủ 48dp). Hệ quả: `reward_track_road` hàng ô thưởng cao cố định (230 x textScale) nên link 48dp gây tràn 1px, đã nâng lên 240. Gỡ 9 mục khỏi baseline `tapTargetSite`, thêm 1 mục báo nhầm (achievement_roadmap_card dòng 193: Semantics ở ngoài cửa sổ 8 dòng của heuristic). Test: 2 khẳng định mới (achievement Claim, friend copy: >= 48 và ancestor `Semantics(button)`), test hiện có của 6 widget giữ xanh. 8 widget này không có golden riêng ngoại trừ `character_collection_grid` (14 golden, chỉ thêm Semantics nên không đổi pixel).
Còn lại cần quyết định riêng (chưa làm): chạm-để-bỏ-qua trên nội dung (`currency_counter`, `offline_earnings_popup`, `reward_sequence_coordinator`) và barrier (`spotlight_overlay:115`, `neon_dialog:179/238`). Chuyển sang ENH-108.

## Tiêu chí xong
Gỡ từng dòng tương ứng khỏi `tool/accessibility_audit_baseline.json` khi sửa xong; audit vẫn xanh.
