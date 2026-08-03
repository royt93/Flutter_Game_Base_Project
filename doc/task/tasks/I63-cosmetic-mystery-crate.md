# I63 — Cosmetic Mystery Crate

**Epic:** Meta/retention (coin sink) · **SP:** 5 · **Pri:** Could
· **Deps:** I30 (Mascot Wardrobe), I51 (Board Frame Cosmetics), I52
(Burst Style), I54 (Combo Text Style)

## Mục tiêu

1 rương "may mắn" tiêu coin, ngẫu nhiên trao 1 cosmetic (mascot skin /
board frame / burst style / combo-text style) mà người chơi CHƯA sở hữu
nhưng ĐÃ đủ điều kiện mở khoá; trùng lặp thì quy đổi thành coin hoàn lại.

## Vì sao

4 hệ thống cosmetic hiện tại (I30/I51/I52/I54) đều mở khoá trực tiếp (mua
hoặc đạt ngưỡng) — chưa có coin sink dạng "gacha nhẹ" tạo cảm giác bất
ngờ, đồng thời giúp tiêu coin dư thừa ở late-game.

## Acceptance criteria

- [ ] `lib/logic/mystery_crate.dart` mới (pure logic) — hàm
  `rollCrate({required List<CosmeticEntry> eligiblePool, required Random rng})`
  trả về 1 `CosmeticEntry` ngẫu nhiên trong pool.
- [ ] `CosmeticEntry` là lớp bọc mỏng (thin wrapper) tổng hợp thông tin từ
  4 hệ thống — **ghi rõ trong code/PR: KHÔNG hợp nhất 4 pattern mở khoá
  khác nhau đã xác nhận cấu trúc khác biệt** (mascot: `coinPrice`/
  `unlockAchievementId` optional; board frame: `BoardFrameUnlockKind` enum
  + `isBoardFrameUnlocked()`; burst/combo-text: `unlockThreshold` +
  hàm `isXUnlocked()` riêng) — ngoài phạm vi task, rủi ro phá 4 tính năng
  đang ổn định.
- [ ] `GameController.rollMysteryCrate()` mới — trừ coin, dựng pool bằng
  cách lọc "đã đủ điều kiện mở khoá nhưng chưa sở hữu/active" qua CẢ 4 hệ
  thống hiện có, gọi `rollCrate()`, cập nhật trạng thái sở hữu đúng theo
  hệ thống tương ứng của item trúng.
- [ ] Trúng trùng (không còn eligible item nào mới, hoặc random rơi vào
  item đã sở hữu — tuỳ thiết kế) → quy đổi coin hoàn lại cố định.
- [ ] Xử lý pool rỗng (đã sở hữu hết mọi cosmetic đủ điều kiện): vô hiệu
  hoá nút mở rương, không cho tiêu coin vô ích.
- [ ] Dialog mở rương mới qua `NeonDialog.overlay` (đúng "Dialog pattern"
  CLAUDE.md, không dùng `Get.dialog`).
- [ ] Unit test `test/logic/mystery_crate_test.dart`: `rollCrate()` chỉ
  trả về item trong pool truyền vào; pool rỗng xử lý đúng (không
  crash/không trả về null không kiểm soát); deterministic với `Random`
  seed cố định.
- [ ] i18n toàn bộ text màn mở rương, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Điểm rủi ro lớn nhất: cố gắng thống nhất 4 pattern unlock thành 1
  interface chung — task này CHỦ ĐỘNG không làm vậy, `CosmeticEntry` chỉ
  là lớp tổng hợp đọc/hiển thị, việc cập nhật trạng thái sở hữu vẫn gọi
  đúng hàm/field gốc của từng hệ thống (4 nhánh switch/if riêng biệt
  trong `rollMysteryCrate()`).
- Giá coin của rương cần đủ cao để không phá cân bằng kinh tế coin hiện
  có (tham khảo giá booster trong `_buy()` để định mức hợp lý).

DoD chung: `../README.md`.
