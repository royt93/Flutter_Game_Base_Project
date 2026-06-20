---
id: w17-4-deepen-b-modes
title: Đào sâu mode B (Vô tận / Soda / Quét màu)
wave: 17
phase: 4
status: todo
owner: claude
---

# Phase 4 — Đào sâu 3 mode 🟡 B (đã có nét riêng, thêm chiều sâu)

Ưu tiên THẤP hơn 17.1–17.3 (3 mode này đã khác luật, không phải reskin). Mục tiêu:
thêm milestone/sự kiện để giữ chân lâu hơn, KHÔNG đổi bản chất.

## Vô tận (Endless)
- **Sự kiện theo stage**: mỗi `kEndlessEventStage` (vd 5 stage) → 1 sự kiện ngắn
  (mưa special / hàng obstacle / x2 điểm 3 lượt). Hiện chỉ "stage tăng → refund ít dần".
- Milestone high-score → badge/danh hiệu.

## Soda (Nước dâng)
- **Vòi xả + ống dẫn**: thêm "vòi" làm mực nước dâng nhanh ở 1 cột; chai trôi theo ống.
  Hiện chỉ là bộ đếm fill → chai. Tạo quyết định không gian (clear cột nào trước).
- Mục tiêu nhiều chai dần theo vòng (endless soda).

## Quét màu (Color Rush)
- **Combo-màu**: clear liên tiếp đúng màu nóng → hệ số nhân tăng dần (×1→×3) rồi reset
  khi miss. Hiện chỉ +15đ/gem phẳng. Thêm "màu nóng kép" ở stage cao.

## Triển khai
- Chủ yếu ở `game_controller_modes.dart` (cfg) + `_*Tick` tương ứng + HUD.
- Tái dùng hook engine có sẵn (gravity/junk/fill) khi cần.

## Test
- Sự kiện/vòi/combo-màu kích đúng ngưỡng; điểm tính đúng; ISOLATION; winnable.

## Lưu ý
Làm SAU 17.1–17.3 (3 reskin cấp bách hơn). Có thể cắt bớt nếu hết thời gian — đây là
"nice to have", không phải fix lỗi-thiết-kế như nhóm 🔴 C.
