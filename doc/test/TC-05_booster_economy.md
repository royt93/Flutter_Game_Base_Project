# TC-05 — Booster & Kinh tế (Xu, Mạng, Shop)

**Phạm vi:** Booster (mua/dùng/nâng cấp), xu, shop, piggy bank  
**Điều kiện tiên quyết:** Có xu trong tài khoản  
**Mức ưu tiên:** P1 (High)

---

## TC-05-01 — Booster: Mua và sử dụng (Hammer)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Shop, bấm mua Hammer (30 xu) | Xu trừ 30, Hammer +1 |
| 2 | Vào màn chơi | Booster Hammer hiển thị trên HUD |
| 3 | Bấm Hammer | Cursor đặc biệt, bấm 1 gem | Gem bị xoá (1 ô) |
| 4 | Hammer đã nâng cấp 3×3, dùng | Xoá vùng 3×3 |
| 5 | Hammer về 0 | Biểu tượng mờ, không dùng được |

---

## TC-05-02 — Booster: +Lượt

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mua booster +Lượt | +Lượt +1 |
| 2 | Vào màn, dùng +Lượt (chưa nâng cấp) | Lượt +10 |
| 3 | Nâng cấp +Lượt (350 xu) | Từ đó trở đi: dùng +Lượt → +15 lượt |

---

## TC-05-03 — Booster: Swap / Bomb / Color / Joker / Lightning / Royal / Gravity

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mua từng loại qua Shop | Số lượng tăng đúng |
| 2 | Dùng trong màn | Hiệu ứng đúng với loại booster |
| 3 | Hết booster | Không cho dùng |
| 4 | Booster nhận từ Battle Pass (Color/Joker/Lightning/Royal) | Cộng đúng vào kho |

---

## TC-05-04 — Nâng cấp Booster Hammer (coin sink)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào Shop / Temple, bấm "Nâng cấp Hammer" (400 xu) | Xu trừ 400, trạng thái nâng cấp lưu |
| 2 | Dùng Hammer sau khi nâng cấp | Xoá vùng 3×3 (không phải 1 ô) |
| 3 | Khởi động lại app | Trạng thái nâng cấp vẫn giữ |

---

## TC-05-05 — Xu: Kiếm và giới hạn

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Thắng màn campaign | Xu tăng (bao gồm streak bonus) |
| 2 | Thắng side mode (3 lần đầu/ngày) | Xu thưởng đầy |
| 3 | Thắng side mode (lần 4+ trong ngày) | Xu giảm ~70% |
| 4 | Vòng quay may mắn thưởng xu | Xu tăng |
| 5 | Xu đạt 2,147,483,647 (int32 max) | Không overflow (clamp) |

---

## TC-05-06 — Shop: Mua gem skin / theme

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Shop | Danh sách skin/theme hiển thị |
| 2 | Bấm mua skin (đủ xu) | Xu trừ đúng, skin unlock |
| 3 | Bấm mua skin (không đủ xu) | Thông báo thiếu xu |
| 4 | Áp skin đã mua | Gem thay đổi hình/màu theo skin |
| 5 | Vào game | Gem render đúng skin đang dùng |

---

## TC-05-07 — Piggy Bank (Heo đất)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chơi nhiều màn tích điểm | Heo đất tích lũy (progress bar) |
| 2 | Heo đất đủ ngưỡng claim | Nút "Đập heo" xuất hiện |
| 3 | Bấm "Đập heo" | Nhận đúng số xu đã tích, không trừ thêm phí |
| 4 | Sau khi đập | Heo đất reset về 0 |
| 5 | Khởi động lại app | Heo đất vẫn 0, không claim lại được |

---

## TC-05-08 — Vòng quay may mắn (Lucky Wheel)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Từ Home, bấm icon bánh xe | Lucky Wheel mở |
| 2 | Quay miễn phí lần đầu trong ngày | Không tốn xu, nhận phần thưởng |
| 3 | Quay lần 2 cùng ngày | Tốn xu hoặc không cho |
| 4 | Sang ngày mới | Lượt quay miễn phí reset |
| 5 | Phần thưởng là xu | Xu cộng vào tài khoản ngay |
| 6 | Phần thưởng là booster | Booster tương ứng +1 |

---

## TC-05-09 — Anti-cheat: chỉnh đồng hồ lùi

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Nhận thưởng ngày hôm nay | Lưu ngày cao nhất đã thấy |
| 2 | Tắt app, chỉnh đồng hồ hệ thống lùi 1 ngày | - |
| 3 | Mở app | App dùng ngày cao nhất đã thấy, KHÔNG cho nhận thưởng lại |
| 4 | Vòng quay, Daily Challenge | Không reset (vẫn đánh dấu đã nhận) |
