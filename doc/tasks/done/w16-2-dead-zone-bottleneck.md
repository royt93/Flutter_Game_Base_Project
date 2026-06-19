---
id: w16-2-dead-zone-bottleneck
title: Dead-zone objectives + tinh chỉnh bottleneck
wave: 16
phase: 2
status: done
owner: claude
---

# Phase 2 — Dead-zone objectives + Bottleneck (tận dụng walls W15)

Theo infographic: đặt mục tiêu vào GÓC CÔ LẬP (dead zone) buộc dùng booster/special;
nút thắt cổ chai (1-2 ô) hạn chế rơi liên mạch → giảm combo tự động (khó hơn).

## Thiết kế
- Weave layout (W15 `kLayoutLevels`) vào vài màn 101-150 sao cho **mục tiêu** (jelly/
  collect/cage) nằm trong góc bị tường cô lập → cần special/booster để chạm.
- Bottleneck: bản đồ tường tạo khe 1-2 ô (kiểu Labyrinth phễu nhưng cho màn thường).
- CHỈ áp ở tier Hard/Super-Hard (Normal giữ thoáng).

## Test (winnability BẮT BUỘC)
- Sim/đọc layout: dead-zone vẫn CHẠM ĐƯỢC (special lan tới); còn ≥1 cặp ô tự do;
  không pocket kẹt. Tái dùng pattern test winnability W14/W15.

## Lưu ý
Góc chết dễ thành bất-khả-thi → mỗi layout PHẢI qua test winnability (bài học W15
Labyrinth). Gắn kinh tế: cần booster → khuyến khích tiêu xu (coin-sink lành mạnh).
