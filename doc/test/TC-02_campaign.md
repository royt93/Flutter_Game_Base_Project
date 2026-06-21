# TC-02 — Campaign: Level Select & Gameplay (Chế độ chính)

**Phạm vi:** Chọn màn, chơi campaign, win/lose flow, mạng  
**Điều kiện tiên quyết:** App đã cài, có ≥1 mạng  
**Mức ưu tiên:** P0 (Critical)

---

## TC-02-01 — Level Select / World Map

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Từ Home, bấm "Chơi" | World Map hoặc Level Select mở |
| 2 | Quan sát màn 1 | Màn 1 mở sẵn (không bị khoá) |
| 3 | Quan sát màn 2 | Màn 2 bị khoá (chưa chơi màn 1) |
| 4 | Bấm vào màn đã unlock | Mở được, chuyển sang GameScreen |
| 5 | Bấm vào màn bị khoá | Không mở được (UI feedback: khoá) |

---

## TC-02-02 — Vào màn & HUD cơ bản

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn 1 (Score Target) | Bàn cờ 8×8 hiển thị, gem rơi xuống |
| 2 | Quan sát HUD | Hiện: ĐIỂM (0), MỤC TIÊU (score), LƯỢT (n) |
| 3 | Quan sát nền | Background neon lung linh (không ảnh hưởng perf) |
| 4 | Quan sát gem | 6 màu gem, mỗi màu hình riêng |
| 5 | Không thao tác 4 giây | Gem gợi ý (hint) phát sáng nhấp nháy |

---

## TC-02-03 — Swap gem cơ bản (tap + swipe)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Tap 1 gem → tap gem kề | Swap thực hiện nếu tạo match |
| 2 | Tap 1 gem → tap gem không kề | Không swap |
| 3 | Swipe gem sang phải | Swap với gem kề bên phải |
| 4 | Swipe gem xuống dưới | Swap với gem kề bên dưới |
| 5 | Swap không tạo match | Gem trả về vị trí cũ (animation) |
| 6 | Swap tạo match | Gem nổ, điểm tăng, LƯỢT giảm 1 |

---

## TC-02-04 — Tạo và kích hoạt gem đặc biệt

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Ghép 4 thẳng hàng | Tạo gem Striped (sọc ngang hoặc dọc) + hiệu ứng birth |
| 2 | Kích hoạt gem Striped | Nổ cả 1 hàng hoặc 1 cột + tia laser beam |
| 3 | Ghép hình T hoặc L | Tạo gem Bomb (vùng 3×3) + hiệu ứng birth |
| 4 | Kích hoạt gem Bomb | Nổ 3×3 + shockwave |
| 5 | Ghép 5 thẳng hàng | Tạo gem Rainbow + hiệu ứng birth |
| 6 | Swap Rainbow + gem thường | Xoá toàn bộ gem cùng màu gem kia |
| 7 | Ghép hình Diagonal (5 chéo) | Tạo Diagonal gem + hiệu ứng riêng |
| 8 | Ghép 6+ hàng | Tạo Light Ball + hiệu ứng birth |

---

## TC-02-05 — Combo 2 gem đặc biệt (Wombo Combo)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Swap Striped + Striped | Nổ chữ thập (1 hàng + 1 cột) |
| 2 | Swap Striped + Bomb | Nổ 3 hàng + 3 cột |
| 3 | Swap Bomb + Bomb | Nổ vùng 5×5 |
| 4 | Swap Rainbow + Striped | Biến gem 1 màu → Striped, rồi tất cả nổ |
| 5 | Swap Rainbow + Bomb | Biến gem 1 màu → Bomb, rồi nổ hết |
| 6 | Swap Rainbow + Rainbow | Xoá sạch cả bàn + màn hình flash |

---

## TC-02-06 — Điểm số & Combo text

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Match 3 gem | Điểm cộng, text "+N" bay lên |
| 2 | Cascade combo ≥2 | Text "COMBO x2" xuất hiện |
| 3 | Combo ≥4 | Haptic nhẹ, text to dần |
| 4 | Combo ≥6 | Text "WOMBO COMBO!" xuất hiện, animation đặc biệt, screen flash, haptic mạnh |
| 5 | Quan sát thanh progress | Thanh animate mượt theo điểm |

---

## TC-02-07 — Auto-shuffle khi hết nước đi

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chơi đến khi bàn không còn nước đi hợp lệ | App tự phát hiện |
| 2 | Quan sát | Text "SHUFFLE!" hiển thị |
| 3 | Quan sát | Bàn bị xáo, gem mới không tạo match sẵn |
| 4 | Tiếp tục chơi | Bình thường |

---

## TC-02-08 — Win: đạt mục tiêu

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Đạt đủ điểm mục tiêu | Dialog thắng hiển thị trong game (overlay) |
| 2 | Quan sát dialog | Hiện số sao (1/2/3), xu thưởng |
| 3 | Bấm nút tiếp tục | Chuyển về Level Select, màn kế unlock |
| 4 | Kiểm tra xu | Xu đã được cộng |
| 5 | Kiểm tra win streak | Win streak tăng 1 |
| 6 | Win streak ≥2 | Xu bonus thưởng thêm |

---

## TC-02-09 — Lose: hết lượt

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Hết lượt (LƯỢT = 0) chưa đạt mục tiêu | Dialog thua hiển thị |
| 2 | Quan sát | Không mở màn kế tiếp |
| 3 | Bấm "Thử lại" | Tốn 1 mạng, chơi lại màn đó |
| 4 | Bấm "Về Home" | Về Home, tốn 1 mạng |
| 5 | Thua 4 lần cùng 1 màn | Lần thứ 5 nhận thêm +2 lượt (pity system, ẩn) |

---

## TC-02-10 — Nút X (thoát giữa chừng)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Đang chơi, bấm nút X | Dialog xác nhận "Bạn có muốn thoát?" |
| 2 | Bấm "Tiếp tục chơi" | Dialog đóng, game tiếp tục |
| 3 | Bấm nút X → bấm "Thoát" | Về Home, tốn 1 mạng |

---

## TC-02-11 — Mạng (Lives system)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Thua 5 lần | Mạng về 0 |
| 2 | Bấm "Chơi" khi 0 mạng | Hiện chip mạng, không vào màn |
| 3 | Đợi 5 phút | 1 mạng hồi tự động |
| 4 | Có ≥60 xu, bấm mua mạng (60 xu) | Mạng đầy 5, xu trừ 60 |
| 5 | Mạng đang đầy 5, bấm mua | Không cho mua (nút mờ hoặc thông báo) |

---

## TC-02-12 — Pre-game Booster

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Chọn màn có booster sẵn | Màn pre-game hiển thị booster có thể bật |
| 2 | Bật 1 booster | Booster active khi vào màn |
| 3 | Chơi màn | Booster hiệu lực (vd Hammer: tapping 1 gem xoá ô đó) |
| 4 | Khi không còn booster | Pre-game không hiện (bỏ qua thẳng vào game) |

---

## TC-02-13 — Obstacle: Jelly

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có mục tiêu "Clear Jelly" | HUD hiện MỤC TIÊU = n jelly còn lại |
| 2 | Ghép gem trên ô jelly | Ô jelly bị xoá |
| 3 | Xoá hết jelly trong lượt | Win dialog hiển thị |

---

## TC-02-14 — Obstacle: Collect

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có mục tiêu "Collect" | HUD hiện số gem màu cần thu |
| 2 | Ghép gem đúng màu target | Số đếm giảm xuống |
| 3 | Thu đủ số lượng | Win dialog hiển thị |

---

## TC-02-15 — Màn có layout đặc biệt (non-rectangular)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Vào màn có ô tường (#) | Ô đó hiển thị khác (không có gem) |
| 2 | Vào màn có ô noDrop (o) | Gem không rơi qua ô đó |
| 3 | Gem rơi theo gravity | Rơi đúng hướng, fill vào ô trống |

---

## TC-02-16 — 200 màn / 10 World (Smoke test)

| # | Bước | Kết quả mong đợi |
|---|------|-----------------|
| 1 | Mở Level Select, cuộn qua tất cả màn | Hiện đủ 200 màn (20 màn/world × 10 world) |
| 2 | Vào màn 1, 50, 100, 150, 200 | Không crash, bàn load đúng |
| 3 | Màn 200 (cuối cùng) sau khi clear | Không crash, hiện màn hoàn thành |
