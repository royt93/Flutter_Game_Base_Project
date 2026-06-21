# TC-01 — First Launch & Màn hình Home

**Phạm vi:** Khởi động lần đầu, hiển thị Home, navigation cơ bản  
**Điều kiện tiên quyết:** Cài app mới (chưa có dữ liệu), kết nối không cần thiết  
**Mức ưu tiên:** P0 (Critical)

---

## TC-01-01 — Khởi động lần đầu (cold start)

**Mục tiêu:** Splash → Home hiển thị đúng, không crash.

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Cài app & mở lần đầu | Splash screen neon hiển thị (logo kim cương) |
| 2 | Chờ ≤3 giây | Chuyển sang Home tự động |
| 3 | Quan sát Home | Logo "Neon Jewels" + glow animation hiển thị |
| 4 | Quan sát số mạng | Hiện 5/5 mạng (đầy — lần đầu cài) |
| 5 | Quan sát xu | Hiện 0 xu (lần đầu) |
| 6 | Quan sát version | Footer hiển thị "vX.Y.Z © SAIGON PHANTOM LABS" |
| 7 | Quan sát nền | Background động: nebula trôi + sao lấp lánh |

**Pass criteria:** Không crash, Home render đầy đủ trong 5 giây.

---

## TC-01-02 — Home: Thưởng đăng nhập ngày đầu

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở app lần đầu | Dialog thưởng đăng nhập xuất hiện (ngày 1: 20 xu) |
| 2 | Nhận thưởng | Xu cộng lên 20, dialog đóng |
| 3 | Thoát app & mở lại cùng ngày | Dialog thưởng KHÔNG xuất hiện lại |
| 4 | Kiểm tra xu | Vẫn 20 xu (không mất) |

---

## TC-01-03 — Home: Navigation tới các màn chính

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Bấm nút "Chơi" (Campaign) | Mở World Map hoặc Level Select |
| 2 | Back về Home | Home hiển thị lại |
| 3 | Bấm "Cài đặt" | Màn Settings mở |
| 4 | Back về Home | Home hiển thị lại |
| 5 | Bấm "Hướng dẫn" | Màn Guide mở |
| 6 | Back về Home | Home hiển thị lại |
| 7 | Bấm "Cửa hàng" | Màn Shop mở |
| 8 | Back về Home | Home hiển thị lại |

---

## TC-01-04 — Home: Cuộn màn hình (màn hình nhỏ)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Dùng thiết bị màn 5" hoặc nhỏ | Nội dung Home hiển thị đủ (không bị cắt) |
| 2 | Kéo xuống | Danh sách chế độ cuộn mượt, không overflow |
| 3 | Kéo lên đầu | Logo + mạng luôn visible ở đầu |

---

## TC-01-05 — Home: Hiển thị badge thông báo

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Có Battle Pass tier chưa nhận | Nút Battle Pass hiển thị badge đỏ |
| 2 | Có Mùa giải phần thưởng chưa nhận | Nút Season League hiển thị badge đỏ |
| 3 | Nhận xong tất cả | Badge biến mất |

---

## TC-01-06 — Toàn màn hình (Full screen / Immersive mode)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Quan sát mọi màn | Status bar hệ thống ẩn |
| 2 | Quan sát mọi màn | Navigation bar hệ thống ẩn |
| 3 | Chơi game | Màn hình không tắt (wakelock active) |
