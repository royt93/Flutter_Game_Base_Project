# I82 — Star Pet có passive nhẹ (đang thuần cosmetic)

**Epic:** E8 Enhance · **SP:** 5 · **Pri:** Should
**Deps:** [[X22]] (sửa exploit idle **trước**) · **Mở rộng:** [[I65]]
**Trạng thái:** 📋 To Do

## Hiện trạng
Star Pet (I65) có: tiền tệ riêng (Star Dust), nhiều loại pet, habitat, thưởng
coin idle theo thời gian rời app. Nhưng pet **không ảnh hưởng gì tới ván
chơi** — thuần sưu tầm + máy sinh coin thụ động.

`star_pets.dart` còn tái dùng `MascotPalette` từ `mascot_skins.dart` thay vì
có bảng màu riêng, nên khác biệt giữa các loại pet gần như chỉ là màu.

## Đề xuất
Mỗi `PetType` mang **một** passive nhẹ, chỉ có tác dụng khi pet đó đang được
"trang bị" (tối đa 1 pet trang bị cùng lúc):

| Pet | Passive đề xuất |
|---|---|
| A | +1 undo miễn phí mỗi màn (chồng với perk `extra_undo`) |
| B | +1 hint mỗi ván (hiện `hintsPerRun = 3`) |
| C | combo window +0.5s |
| D | +5% coin thưởng cuối màn (chồng với perk `coin_bonus`) |
| E | 1 gift tile thêm mỗi màn có gift |

Con số là điểm khởi đầu. Giữ **tất cả** ở mức "dễ chịu", không mức nào đổi
được thắng-thua.

## Vì sao Should
Cho một hệ đã tồn tại một lý do tồn tại — rẻ hơn nhiều so với xây hệ mới.
Đồng thời cho Star Dust (tiền tệ thứ hai, hiện chỉ để ấp pet trang trí) một
điểm đến thật.

Không Must vì nó chồng lên hệ perk đã có (F14) — rủi ro chính là hai hệ
tăng-sức-mạnh song song, không hệ nào rõ ràng.

## User story
*As a* người chơi sưu tầm pet *I want* pet tôi chọn tạo khác biệt nhỏ trong
ván *so that* việc chọn pet là một quyết định, không chỉ là chọn màu.

## Acceptance criteria
- [ ] Đúng **1** pet được trang bị cùng lúc; đổi ở `pet_habitat_screen`;
      lưu bằng key mới theo nếp `StorageKeys` hiện có.
- [ ] Passive **chỉ** áp dụng khi pet được trang bị; đọc qua một getter duy
      nhất trên `GameController` (khuôn `hasPerk(id)` đã có), không rải
      `if (pet == …)` khắp nơi.
- [ ] Passive **cộng dồn** với perk F14, không thay thế. Trần cứng: tổng số
      undo miễn phí ≤3, hint ≤5 — chốt trần trong code, không để cộng vô hạn.
- [ ] Không passive nào áp dụng ở mode dùng best-score (timeAttack, comboRush,
      frostRush, endless, mirror) — nếu không, mọi kỷ lục cũ bị vô hiệu.
      **Đây là AC bắt buộc**, không phải tuỳ chọn.
- [ ] `_load()` re-validate pet đang trang bị theo `kStarPetTypes` hiện tại
      (đúng khuôn mọi hệ id khác — xem CLAUDE.md, mục Storage).
- [ ] UI hiện rõ passive của pet đang trang bị, đã i18n 22 ngôn ngữ.
- [ ] Test: `test/logic/star_pets_test.dart` + `game_controller_test.dart`
      (cover trần và loại trừ side-mode).

## Subtask
1. `star_pets.dart` — thêm field passive vào `PetType` (enum + giá trị).
2. `game_controller.dart` — `equippedPet` (Rx + persist + re-validate),
   getter `petPassive`, nối vào `_freeUndoLeft`, `hintsPerRun`,
   `activeComboWindowOverride`, `_grantCoins`.
3. Loại trừ side-mode ở từng điểm nối.
4. `pet_habitat_screen.dart` — nút trang bị + mô tả passive.
5. i18n + test.

## Rủi ro
- **Cảm giác pay-to-win** dù không có IAP: Star Dust chỉ kiếm bằng thắng
  3 sao campaign và Daily Challenge, nên nó là phần thưởng cho kỹ năng.
  Giữ nguyên đường kiếm đó, đừng thêm đường mua bằng coin.
- **Chồng chéo với perk F14**: nếu sau khi làm xong thấy 2 hệ nói cùng một
  điều, cân nhắc gộp — nhưng gộp là task riêng, không nhét vào đây.

## Ghi chú
Làm sau [[X22]]. Nếu gắn passive vào pet trong khi vẫn còn farm được coin
idle bằng chỉnh đồng hồ, tự dưng passive cũng farm được theo.

DoD chung: `../README.md`.
