# TC-07 — Settings, i18n, Audio, Guide

**Phạm vi:** Cài đặt, đa ngôn ngữ, âm thanh, hướng dẫn  
**Điều kiện tiên quyết:** App đã khởi động  
**Mức ưu tiên:** P1 (High)

---

## TC-07-01 — Settings: Âm thanh

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Settings | Nút tắt/bật nhạc nền và SFX |
| 2 | Tắt nhạc nền | Nhạc nền dừng lại ngay |
| 3 | Bật lại nhạc nền | Nhạc phát lại |
| 4 | Tắt SFX | Âm thanh hiệu ứng (match, nổ) tắt |
| 5 | Bật lại SFX | Âm thanh hiệu ứng phát trở lại |
| 6 | Khởi động lại app | Trạng thái âm thanh được lưu |

---

## TC-07-02 — Settings: Chọn ngôn ngữ

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Settings → Ngôn ngữ | Danh sách 22 ngôn ngữ |
| 2 | Chọn "Tiếng Việt" | Toàn bộ UI chuyển sang tiếng Việt, font Baloo2 |
| 3 | Kiểm tra dấu thanh | "Điểm", "Lượt", "Mục tiêu" hiển thị đúng dấu |
| 4 | Chọn "English" | UI chuyển sang tiếng Anh, font Orbitron |
| 5 | Chọn ngôn ngữ khác (vd Spanish) | UI dịch tương ứng |
| 6 | Khởi động lại app | Ngôn ngữ đã chọn được giữ |

---

## TC-07-03 — Settings: Reset tiến độ

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm "Xoá tiến độ" | Dialog xác nhận xuất hiện |
| 2 | Bấm "Huỷ" | Không có gì xảy ra |
| 3 | Bấm "Xoá tiến độ" → "Xác nhận" | Tất cả dữ liệu xoá |
| 4 | Kiểm tra sau reset | Màn = 1, xu = 0, mạng = 5, booster = 0 |
| 5 | Kiểm tra Battle Pass | Reset về tier 0 |
| 6 | Kiểm tra Achievement | Reset về 0 |
| 7 | Khởi động lại app | Trạng thái vẫn là fresh start |

---

## TC-07-04 — Guide Screen (Hướng dẫn)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Guide | Màn hướng dẫn có scroll |
| 2 | Đọc phần "Cách chơi" | Mô tả swap, match-3 rõ ràng |
| 3 | Đọc phần "Gem đặc biệt" | Striped / Bomb / Rainbow / Diagonal / LightBall mô tả đủ |
| 4 | Đọc phần "Combo" | Bảng kết hợp 2 gem đặc biệt |
| 5 | Đọc phần "Các chế độ" | Liệt kê tất cả mode với mô tả |
| 6 | Cuộn hết | Không bị overflow, nội dung không bị cắt |
| 7 | Back | Về Home |

---

## TC-07-05 — Audio: Combo sfx

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Ghép combo liên tiếp | Âm thanh cao dần theo combo (24 nốt tăng dần) |
| 2 | Combo break | Nốt nhạc reset |
| 3 | Ghép rainbow | Âm thanh rainbow riêng biệt |
| 4 | SFX tắt | Không nghe tiếng dù combo cao |
