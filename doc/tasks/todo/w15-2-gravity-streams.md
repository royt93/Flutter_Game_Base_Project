---
id: w15-2-gravity-streams
title: Dòng chảy Neon / Gravity Streams (cơ chế ĐỘC QUYỀN)
wave: 15
phase: 2
status: todo
owner: claude
---

# Phase 2 — Gravity Streams (signature)

Cơ chế trọng lực độc quyền: vùng có **mũi tên neon** đổi HƯỚNG trọng lực cục bộ
(xuống/trái/phải/lên). Gem chảy theo hướng của vùng nó đang ở → bàn như mạch điện.
Phase NẶNG nhất — tổng quát hoá toàn bộ settle engine.

## Thiết kế
- Lưới `flowDir: List<List<Dir>>` (Dir = down/up/left/right), mặc định down (khớp
  hành vi cũ). Khai báo qua bản đồ ký tự mở rộng (`v ^ < >`).
- Tổng quát hoá settle: thay "luôn rơi xuống" bằng "di chuyển theo `flowDir[r][c]`
  tới khi gặp wall/biên/gem chặn". Refill từ **mép-nguồn** của mỗi dòng chảy
  (ô đầu dòng, hướng ngược flow). Phải TẤT ĐỊNH + hội tụ (chống lặp vô hạn:
  cấm chu trình hướng — validate ở build level).
- `FlowLayer` render mũi tên neon chạy (animate theo hướng).
- Tích hợp với wall (Phase 0) + trượt chéo (Phase 1): trượt chéo tính theo hướng
  flow cục bộ (vuông góc với flow).

## Test
- Dòng ngang (gem chảy sang phải/trái) settle đúng + refill từ mép nguồn; bố cục
  hỗn hợp hướng hội tụ không lặp; build level cấm chu trình hướng; tất định.
- Winnability: bàn stream luôn còn nước đi / auto-shuffle đúng.

## Lưu ý
Vì đụng lõi gravity, làm SAU khi Phase 0+1 đã verify máy thật. Cân nhắc tách hàm
settle thuần (pure Dart, test không cần Flame) để kiểm tra logic chảy độc lập.
