# TC-10 — Regression & Edge Cases

**Phạm vi:** Các trường hợp biên, bug đã biết, anti-exploit  
**Mức ưu tiên:** P1 (High) — chạy trước mỗi release

---

## TC-10-01 — Dialog không bị mất (in-tree overlay)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Hết lượt (thua) | Win/Lose dialog PHẢI hiển thị (không bị mất) |
| 2 | Đạt mục tiêu (thắng) | Win dialog PHẢI hiển thị |
| 3 | Bấm X giữa game | Dialog xác nhận PHẢI hiển thị |
| 4 | Hết lượt khi đang có cascade | Cascade xong → dialog xuất hiện (không bị kẹt) |
| **CHÚ Ý:** | Get.dialog / showDialog là no-op trong Flame | Dialog PHẢI là NeonDialog.overlay in-tree |

---

## TC-10-02 — Lượt 0 → dialog xuất hiện (không bị skip)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | LƯỢT = 1, thực hiện 1 nước đi xấu (không match) | LƯỢT về 0 → Lose dialog xuất hiện ngay |
| 2 | LƯỢT = 1, match lớn gây cascade dài | Cascade hoàn tất → LƯỢT về 0 → dialog xuất hiện |
| 3 | Dùng booster khi LƯỢT = 0 | Không cho dùng |

---

## TC-10-03 — Reactive: MỤC TIÊU Jelly hiện đúng

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn Clear Jelly | HUD MỤC TIÊU hiển thị N/TOTAL (không phải 0/0) |
| 2 | Xoá 1 ô jelly | Counter cập nhật ngay |

---

## TC-10-04 — Reset tiến độ: không re-claim exploit

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Nhận thưởng Battle Pass tier 3 | Ghi nhận đã nhận |
| 2 | Reset tiến độ trong Settings | Cả đĩa lẫn in-memory đều cleared |
| 3 | Khởi động lại app | Battle Pass về tier 0, không có phần thưởng cũ |
| 4 | Đạt lại tier 3 | Nhận bình thường (không bị khóa) |

---

## TC-10-05 — Side mode không ảnh hưởng campaign

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chơi Endless 10 lần | Màn campaign đang ở bị lock vẫn locked |
| 2 | Thắng Boss nhiều lần | Win streak campaign KHÔNG tăng |
| 3 | Thua Gravity nhiều lần | Mạng campaign KHÔNG bị trừ |

---

## TC-10-06 — Xu không overflow

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Debug: set xu về 2,147,483,600 | Hiển thị số lớn đúng format |
| 2 | Thắng màn thêm xu | Xu dừng tại 2,147,483,647 (không overflow sang âm) |
| 3 | Mua item | Xu trừ bình thường |

---

## TC-10-07 — Font tiếng Việt (Baloo2, không dùng Orbitron cho vi)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chọn ngôn ngữ Tiếng Việt | Font Baloo2 áp dụng |
| 2 | Kiểm tra "Điểm", "Lượt", "Mục tiêu" | Hiển thị đầy đủ dấu thanh, không bị vuông/lỗi font |
| 3 | Chọn lại English | Font Orbitron, không dấu tiếng Việt |

---

## TC-10-08 — Cascade không leak

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Tạo chain reaction dài (≥5 cascade) | Tất cả gem rơi đúng vị trí |
| 2 | Sau cascade | Bàn không có ô trống lạ, không có gem bay ngoài bàn |
| 3 | Tiếp tục chơi | Không bị lag hoặc crash |

---

## TC-10-09 — Gravity Flip không để lại state

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chơi Gravity, gravity flip xảy ra | Gem rơi ngược |
| 2 | Thoát Gravity mode | State flip KHÔNG lan sang màn campaign |
| 3 | Vào campaign | Gem rơi xuống bình thường |

---

## TC-10-10 — Kiểm tra phiên bản app

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Xem footer Home | Hiển thị version từ pubspec.yaml (package_info_plus) |
| 2 | Update pubspec version | Footer tự cập nhật (không hardcode) |

---

## TC-10-11 — Performance cơ bản

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chơi 10 phút liên tục | Không drop xuống <30fps rõ rệt |
| 2 | Combo lớn (rainbow + rainbow) | Hiệu ứng mượt, không giật |
| 3 | Mở/đóng nhiều màn liên tiếp | Không memory leak (app không bị kill) |

---

## TC-10-12 — Màn hình nhỏ (5 inch) không overflow

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chạy trên thiết bị 5" | Không có widget bị overflow |
| 2 | Bàn 8×8 | Vẫn hiển thị đủ |
| 3 | HUD | Chip ĐIỂM/MỤC TIÊU/LƯỢT không wrap |
