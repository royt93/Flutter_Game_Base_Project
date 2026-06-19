---
id: w15-1-diagonal-slide
title: Trượt chéo kiểu Candy Crush (gravity vòng qua vật cản)
wave: 15
phase: 1
status: done
owner: claude
---

# Phase 1 — Diagonal-slide gravity

Sau Phase 0 (lỗ-cắt-cột), bổ sung gem **trượt chéo** vòng qua vật cản giống CCS:
khi ô ngay dưới gem bị chặn (wall) mà ô chéo dưới-trái/dưới-phải trống + có "nguồn
gem" phía trên-chéo, gem trượt chéo vào chỗ trống thay vì kẹt cứng.

## Thiết kế
- Tổng quát hoá `_applyGravityAndRefill`: sau bước dồn thẳng đứng, lặp pass
  "trượt chéo": với mỗi ô trống không có gem rơi thẳng được (bị wall chặn trên),
  hút gem từ ô trên-chéo (ưu tiên 1 hướng tất định để KHÔNG dao động). Lặp tới khi
  ổn định.
- Đảm bảo TẤT ĐỊNH (không random) để test & tránh nhấp nháy vô hạn.
- Animation: gem trượt chéo dùng tween vị trí (tái dùng cơ chế rơi sẵn có).

## Test
- Bố cục "mái che" (wall che cột, lỗ chéo bên dưới) → gem trượt chéo lấp đầy, KHÔNG
  để lại lỗ giả; settle hội tụ (không lặp vô hạn); tất định cùng input → cùng output.
