# TC-03 — Side Modes (Các chế độ phụ)

**Phạm vi:** 13 challenge entries: Daily, Endless, Boss, Color Rush, Gravity, Zen, Rhythm, 2 Players, Soda, Survival, Labyrinth, Puzzle, Rush  
**Điều kiện tiên quyết:** Không cần mạng; side mode KHÔNG tốn mạng, KHÔNG unlock màn campaign  
**Mức ưu tiên:** P1 (High)

---

## TC-03-01 — Nguyên tắc chung Side Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Thắng bất kỳ side mode | Không tăng số màn campaign đã unlock |
| 2 | Thua bất kỳ side mode | Không trừ mạng |
| 3 | Thắng 4+ side mode cùng ngày | Lần 1-3: xu thưởng đầy. Lần 4+: xu giảm ~70% (chống farm) |

---

## TC-03-02 — Endless Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Từ Home, bấm "Vô tận" | Game bắt đầu, stage = 1 |
| 2 | Chơi tích điểm | Stage tự động tăng khi đạt ngưỡng |
| 3 | Mỗi N stage | Sự kiện ngẫu nhiên kích hoạt (DoubleScore, ExtraShuffleCharge...) |
| 4 | Bấm X thoát | Điểm cao nhất được lưu |
| 5 | Mở lại Endless | Corner chip hiển thị điểm cao cũ |

---

## TC-03-03 — Boss Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Boss", chọn stage 1 | Màn boss load, có thanh máu boss |
| 2 | Ghép gem màu không phải điểm yếu | Sát thương thấp |
| 3 | Ghép gem đúng màu điểm yếu | Sát thương cao hơn |
| 4 | Máu boss < 50% | Màu điểm yếu đổi sang màu khác (phase 2) |
| 5 | Máu boss = 0 | Win dialog |
| 6 | Hết lượt (máu boss > 0) | Lose dialog |
| 7 | Chọn stage 2, 3... | Máu boss cao hơn stage trước |

---

## TC-03-04 — Gravity Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Trọng lực" | Game bắt đầu, gem rơi xuống (hướng mặc định) |
| 2 | Chơi N lượt | Hướng rơi đảo ngược (trên → dưới hoặc ngược lại) |
| 3 | Quan sát gem sau flip | Gem rơi đúng hướng mới |
| 4 | Đạt điểm mục tiêu | Win dialog |

---

## TC-03-05 — Rhythm Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Nhịp điệu" | Game bắt đầu, nhạc phát + HUD hiện beat indicator |
| 2 | Swap gem đúng nhịp beat | Groove tăng, "+BEAT" feedback |
| 3 | Swap gem lệch nhịp | Groove giảm |
| 4 | Groove cao (≥4) | Điểm thưởng hệ số tăng (×1.5 → ×2.5) |
| 5 | HUD beat đập nhịp | Thanh beat pulse theo nhạc |

---

## TC-03-06 — Color Rush Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Color Rush" | Game bắt đầu, 1 màu "nóng" được hiển thị |
| 2 | Ghép đúng màu nóng liên tiếp | Streak tăng (×1 → ×2 → ×3), bonus điểm |
| 3 | Ghép màu khác | Streak reset về 0 |
| 4 | Màu nóng thay đổi định kỳ | Màu mới được hiển thị, streak reset |

---

## TC-03-07 — Soda Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Soda" | Game bắt đầu, có chai soda + mực nước ở đáy |
| 2 | Ghép gem | Mực nước dâng lên |
| 3 | Mực nước đẩy chai lên đỉnh | 1 chai hoàn thành |
| 4 | Đủ N chai trong lượt | Win dialog |
| 5 | Hết lượt chưa đủ chai | Lose dialog |

---

## TC-03-08 — Survival Mode (Sinh tồn / Triều dâng)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Sinh tồn" | Game bắt đầu, overlay triều dâng xuất hiện |
| 2 | Đợi không chơi | Nước dâng từ đáy lên theo thời gian |
| 3 | Clear gem dưới nước | Nước bị đẩy lùi |
| 4 | Nước chạm đỉnh | Game kết thúc, điểm được lưu làm kỷ lục |
| 5 | Mở lại Survival | Corner chip hiển thị điểm kỷ lục cũ |

---

## TC-03-09 — Labyrinth Mode (Mê cung)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Mê cung" | Game bắt đầu, bàn có tường động |
| 2 | Quan sát bàn | Một số ô bị sương mù (fog-of-war) |
| 3 | Ghép gem trong ô thấy | Ô xung quanh dần lộ ra |
| 4 | Tường di chuyển định kỳ | Bàn thay đổi cấu trúc |
| 5 | Đạt tinh thể mục tiêu | Win dialog |

---

## TC-03-10 — Daily Challenge (Thử thách hằng ngày)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Thử thách ngày" | Màn được tạo từ seed theo ngày |
| 2 | Quan sát mutator | 1–3 biến thể đặc biệt áp vào màn (hiển thị rõ) |
| 3 | Thắng lần đầu trong ngày | Nhận xu thưởng, lưu "đã nhận" |
| 4 | Chơi lại cùng ngày | Được chơi lại nhưng KHÔNG nhận xu thêm |
| 5 | Sang ngày mới | Bàn mới (seed mới), có thể nhận xu lại |
| 6 | Ngày giống nhau trên 2 thiết bị | Cùng bàn cờ (seed theo ngày) |

---

## TC-03-11 — Puzzle Mode (Cấu đố)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Cấu đố" | Danh sách cấu đố mở (PuzzleSelectScreen) |
| 2 | Chọn 1 cấu đố | Game bắt đầu, bàn seed cố định |
| 3 | Quan sát | Không có gem mới rơi xuống (no-refill) |
| 4 | Đạt điểm mục tiêu trong lượt | Win |
| 5 | Cùng cấu đố, chơi lại từ đầu | Bàn giống hệt (seed cố định) |
| 6 | Hết lượt chưa đạt | Lose, có thể thử lại |

---

## TC-03-12 — Zen Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Zen" | Game bắt đầu, lượt hiện 999 (vô hạn) |
| 2 | Chơi thoải mái | Không có giới hạn lượt, không thua |
| 3 | Bấm X | Dialog xác nhận thoát |
| 4 | Xác nhận thoát | Điểm cao nhất lưu làm kỷ lục Zen |
| 5 | Mở lại Zen | Corner hiển thị điểm cao cũ |

---

## TC-03-13 — Rush Mode

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Rush" | Game bắt đầu với timer 02:00 |
| 2 | Ghép liên tục | Score tăng nhanh, match tốt có time bonus |
| 3 | Timer hết | Game kết thúc, điểm lưu làm kỷ lục Rush |
| 4 | Bấm Again | Restart vẫn là Rush, không rơi về campaign |
