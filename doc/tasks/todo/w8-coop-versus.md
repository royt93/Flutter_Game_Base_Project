---
id: w8-coop-versus
title: Co-op / Versus cục bộ (signature)
wave: 8
status: todo
owner: claude
---

# Đối kháng / Hợp tác cục bộ (cùng thiết bị)

> ĐỘC QUYỀN & KHÁC BIỆT vs Candy Crush (vốn không có versus thật). KHÓ NHẤT
> trong 4 tính năng → làm cuối. Bản đầu: **offline cùng máy** (không cần backend).

## 2 biến thể
- **Versus (đua điểm)**: 2 lưới cạnh nhau (hoặc luân phiên lượt). Trong T giây ai
  nhiều điểm hơn thắng. Ghép special có thể "gửi rác" (junk gem) sang đối thủ.
- **Co-op (chung mục tiêu)**: 2 người chung 1 lưới lớn / 2 lưới góp điểm vào 1
  mục tiêu (vd cùng đạt 5000đ trước khi hết giờ).

## Việc cần làm
- Tách `NeonJewelGame` để chạy **2 instance độc lập** (state riêng) trên 1 màn.
- Layout split: dọc (trên/dưới) cho 2 người ngồi đối diện — xoay HUD người trên 180°.
- "Attack/junk" interaction giữa 2 lưới (versus).
- Màn chọn chế độ + đếm ngược + panel kết quả "Người 1 / Người 2 thắng".

## Rủi ro
- Hiệu năng: 2 Flame game cùng lúc trên máy yếu → cần profile.
- Phức tạp input đồng thời (2 vùng tap riêng).
- Online/matchmaking để SAU (cần backend, ngoài phạm vi offline-first hiện tại).

## Test
- 2 instance state độc lập không rò rỉ sang nhau; tính điểm thắng/thua/hoà đúng;
  junk gem bơm sang đúng lưới.
