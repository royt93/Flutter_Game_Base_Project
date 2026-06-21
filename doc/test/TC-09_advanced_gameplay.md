# TC-09 — Gameplay Nâng cao (Conveyor, Portal, Dispenser, Flow Gravity, Cage, Order)

**Phạm vi:** Các cơ chế board đặc biệt được weave vào campaign  
**Điều kiện tiên quyết:** Đã unlock đến màn tương ứng có cơ chế  
**Mức ưu tiên:** P2 (Medium)

---

## TC-09-01 — Order Gems (Màn Order)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có mục tiêu Order | HUD hiện danh sách order (gem màu + số lượng) |
| 2 | Ghép gem đúng order | Số order giảm xuống |
| 3 | Hoàn thành tất cả order | Win |
| 4 | Hết lượt chưa đủ | Lose |

---

## TC-09-02 — Bomb Gem (match hình T/L → Bomb)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Ghép hình T hoặc L (5 gem) | Gem Bomb xuất hiện tại giao điểm |
| 2 | Kích hoạt Bomb | Xoá vùng 3×3 xung quanh |
| 3 | Bom nằm trong vùng nổ | Chain reaction |

---

## TC-09-03 — Light Ball (match 6+)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Ghép ≥6 gem thẳng hàng | Light Ball xuất hiện |
| 2 | Kích hoạt Light Ball | Hiệu ứng mạnh hơn rainbow thường |

---

## TC-09-04 — Diagonal Gem (match chéo 5)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Ghép 5 gem theo đường chéo | Diagonal gem xuất hiện |
| 2 | Kích hoạt | Nổ theo đường chéo |

---

## TC-09-05 — Conveyor Belt (Băng chuyền)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có băng chuyền | Ô băng chuyền có mũi tên hướng |
| 2 | Sau mỗi nước đi | Gem trên băng chuyền di chuyển theo hướng mũi tên |
| 3 | Gem ra khỏi băng chuyền | Gem rơi xuống vị trí tiếp theo |

---

## TC-09-06 — Portal (Cổng dịch chuyển)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có cổng (cặp A–A, B–B...) | Cổng hiển thị cặp màu nhận biết |
| 2 | Gem rơi vào cổng đầu vào | Gem xuất hiện tại cổng đầu ra |

---

## TC-09-07 — Dispenser (Máy phân phát)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có dispenser | Dispenser ở cạnh bàn |
| 2 | Gem kề dispenser bị xoá | Dispenser phát gem mới |

---

## TC-09-08 — Flow Gravity Streams

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có flow direction (v/^/</>)  | Ô đó có mũi tên |
| 2 | Gem rơi qua ô flow | Gem bị "uốn" theo hướng mũi tên |
| 3 | Gem không rơi qua noDrop | Ô o ngăn gem rơi xuống |

---

## TC-09-09 — Cage Obstacle (Lồng)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có lồng | Gem trong lồng hiển thị khóa |
| 2 | Ghép gem kề ô lồng | Lồng vỡ 1 lớp |
| 3 | Vỡ hết lớp | Gem giải phóng, có thể ghép |

---

## TC-09-10 — Tide / Soda Layer (Wave 14)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn Soda | Lớp soda overlay ở đáy bàn |
| 2 | Xoá gem | Mực soda dâng theo số gem xoá |
| 3 | Mực đến vị trí chai | Chai "nổi" và tính vào số chai hoàn thành |

---

## TC-09-11 — Jam Obstacle (Kẹt)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có jam (ô kẹt) | Ô jam hiển thị texture đặc biệt |
| 2 | Ghép gem kề | Jam lan sang ô lân cận (giới hạn) |
| 3 | Xoá hết jam | Mục tiêu jam hoàn thành |
| 4 | Số ô jam là cố định | Luôn có thể thắng (không grow vô hạn) |
