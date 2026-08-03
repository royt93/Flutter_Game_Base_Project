# I65 — Star Pet & Companion Habitat

**Epic:** Meta/retention (collection, idle) · **SP:** 8 · **Pri:** Could
· **Deps:** I30 (Mascot Wardrobe, chỉ tham khảo pattern)

## Mục tiêu

Hệ thống "thú cưng sao" thu thập được (khác mascot chính, có thể sở hữu
NHIỀU pet cùng lúc) sống trong 1 "chuồng" (habitat) trên màn riêng, tích
luỹ phần thưởng idle (Star Dust/coin) theo thời gian rời app, thu thập
qua hoàn thành level 3 sao/Daily Challenge.

## Vì sao

Mascot (I30) là 1 nhân vật đồng hành DUY NHẤT, thay trang phục. Star Pet
là lớp sưu tầm khác hẳn: nhiều thực thể độc lập cùng lúc + phần thưởng
idle — tạo lý do quay lại "thu hoạch" đều đặn mà hệ mascot hiện tại không
đáp ứng.

## Acceptance criteria

- [ ] `lib/data/star_pets.dart` mới — bảng loại pet + class `PetInstance`
  (kiến trúc đa-thực-thể, khác hẳn mascot 1 instance duy nhất).
- [ ] `StorageKeys.starDustCount` (currency), `starOwnedPets` (danh sách
  pet sở hữu, encode JSON), `lastPetCollectTimestampMs` — **key MỚI hoàn
  toàn, không tái dùng `lastOpenDay`** (`storage_service.dart` dòng 46)
  vì key đó chỉ có độ chính xác theo NGÀY, không đủ cho tính thưởng idle
  theo giờ.
- [ ] Star Dust trao khi hoàn thành level 3 sao hoặc hoàn thành Daily
  Challenge (hook vào điểm kết thúc level tương ứng đã có).
- [ ] Hàm pure `idleRewardCoins({required int lastCollectMs, required int
  nowMs, required int petCount})` — có mức trần thời gian tối đa (vd
  8-12h) để chặn tích luỹ vô hạn nếu người chơi rời app quá lâu; xử lý an
  toàn khi `nowMs < lastCollectMs` (đồng hồ máy bị lùi) — không được trả
  về âm/overflow, trả về 0 trong trường hợp này.
- [ ] Widget mới `lib/presentation/widgets/star_pet_habitat.dart` — chỉ
  tham khảo cách vẽ của `StarMascot`/`_StarPainter` (`star_mascot.dart`)
  làm layout reference, **không sửa `StarMascot`** (tránh ảnh hưởng I30)
  — widget hoàn toàn mới hỗ trợ hiển thị nhiều pet instance cùng lúc.
- [ ] Màn hình mới `pet_habitat_screen.dart` để nở/thu thập pet + nhận
  thưởng idle.
- [ ] **Ràng buộc bắt buộc**: pet KHÔNG được hiển thị đè lên bàn chơi
  trong lúc chơi game (tương tự tinh thần R4 CLAUDE.md về việc không che
  UI) — pet chỉ xuất hiện ở màn Habitat/home, không bao giờ render trong
  `game_screen.dart`.
- [ ] Unit test mới `test/logic/star_pets_test.dart` (hoặc tương đương):
  `idleRewardCoins()` đúng công thức, trần thời gian hoạt động đúng, xử
  lý an toàn khi thời gian âm/đồng hồ lùi.
- [ ] i18n toàn bộ text màn Habitat, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Gap xác nhận: `checkComebackBonus()` (`game_controller.dart` dòng
  997-1010) và `lastOpenDay` chỉ có độ phân giải NGÀY — không đủ cho
  công thức idle-theo-giờ, bắt buộc timestamp mili-giây riêng.
- `StarMascot` (`star_mascot.dart` dòng 30) là kiến trúc single-instance
  (1 `AnimationController`, 1 mood) — không mở rộng được trực tiếp cho
  nhiều pet, đây là lý do phải viết widget mới thay vì tái dùng.
- Đây là task SP cao (8) — nếu vượt scope khi triển khai, cân nhắc giảm
  số loại pet ở bản đầu (vd 3 loại) thay vì cắt giảm phần idle-reward
  (phần lõi tạo giá trị retention).

DoD chung: `../README.md`.
