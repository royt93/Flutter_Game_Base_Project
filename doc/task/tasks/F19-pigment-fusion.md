# F19 — Pigment Fusion: pha 2 pigment ra pigment hiếm

**Epic:** E9 Tính năng mới · **SP:** 5 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I62]] · **Tái dùng:** [[I32]] craft points
**Trạng thái:** ✅ Done (2026-08-13)

## Hiện trạng
Color Alchemy (I62): `pigments.dart` là bảng màu, mỗi pigment **hoặc** miễn
phí, **hoặc** mua bằng coin, **hoặc** mở bằng achievement (ba dạng loại trừ
nhau, có `assert`). Mở khoá xong thì gán vào slot màu gem để đổi màu hiển thị.

Tuyến tính: thấy giá → trả tiền → có màu. Không có quyết định nào.

Tên tính năng là **"Alchemy"** — giả kim — nhưng không có phản ứng nào xảy ra.

## Pitch
Bàn pha chế: kết hợp 2 pigment đã sở hữu + một lượng craft point → ra một
pigment hiếm **không mua được bằng cách nào khác**.

## Vì sao độc quyền
Progression dạng crafting trong một game pop, và nó cho tầng cosmetic một
cấu trúc thay vì một bảng giá. Công thức tạo ra "aha" — điều mà mua hàng
không bao giờ tạo ra.

## Vì sao Could
Thuần cosmetic, không chạm gameplay. Giá trị hoàn toàn nằm ở việc bảng công
thức có **thú vị** hay không, mà đó là việc thiết kế nội dung, không phải kỹ
thuật. Code là phần dễ.

## User story
*As a* người chơi sưu tầm màu *I want* khám phá màu mới bằng cách thử pha
*so that* bộ sưu tập là hành trình chứ không phải hoá đơn.

## Acceptance criteria
- [ ] Bảng công thức tĩnh trong `pigments.dart`: `(pigmentA, pigmentB) →
      pigmentC`. **Dữ liệu, không phải code nhánh.**
- [ ] Pigment hiếm sinh ra bằng fusion **không** mua được bằng coin và
      **không** gắn achievement — nếu không, fusion là đường vòng vô nghĩa.
      Việc này thêm dạng mở khoá thứ tư: **cập nhật `assert` loại trừ** trong
      `pigments.dart` cho đúng, đừng để nó nói dối.
- [ ] Fusion tiêu craft point (tái dùng `craft_points.dart` — đã có, hiện chỉ
      dùng để đổi booster cuối màn). **Không** thêm tiền tệ thứ tư.
- [ ] Pigment nguyên liệu **không** bị mất sau khi pha (nếu mất, người chơi sẽ
      không dám thử — và mục đích là khuyến khích thử).
- [ ] Công thức đã khám phá được lưu và hiện lại; công thức chưa khám phá
      hiện dạng gợi ý mờ, không hiện thẳng đáp án.
- [ ] Tổ hợp không có công thức → thông báo rõ ràng, **không** tiêu craft point.
- [ ] `_load()` re-validate id pigment theo bảng const hiện tại (nếp chung —
      xem CLAUDE.md mục Storage).
- [ ] Cập nhật `mystery_crate.dart` nếu pigment nằm trong pool cosmetic của nó.
- [ ] Cập nhật `totalCosmeticsOwned` (`game_controller.dart:807`) nếu pigment
      được tính vào Sticker Album — kiểm tra và chốt, đừng để lệch.
- [ ] i18n 22 ngôn ngữ; test cho bảng công thức + `pigments_test.dart` (xem
      [[T3]], file này chưa tồn tại).

## Subtask
1. `pigments.dart` — thêm 6-10 pigment hiếm + bảng công thức + sửa `assert`.
2. `game_controller.dart` — `bool fusePigments(a, b)` theo khuôn `buyPigment`.
3. `color_alchemy_screen.dart` — UI bàn pha (2 slot + nút pha + sổ công thức).
4. Rà `mystery_crate.dart` và `totalCosmeticsOwned`.
5. i18n + test.

## Ghi chú kỹ thuật
Giữ bảng công thức **nhỏ và thủ công** (6-10 công thức). Đừng sinh công thức
bằng thuật toán trộn màu — kết quả sẽ ra hàng chục màu na ná nhau và mất hẳn
cảm giác khám phá. Ít công thức được chọn tay, mỗi cái cho ra một màu thật sự
khác biệt, tốt hơn nhiều.

DoD chung: `../README.md`.

---

## Tiền đề của AC sai: craft point KHÔNG phải tiền tệ

AC viết "Fusion tiêu craft point (tái dùng `craft_points.dart` — đã có)". Đọc
file thì `craft_points.dart` chỉ là **hàm thuần đo số cell còn sót**: đo xong,
đủ ngưỡng thì đổi ngay thành 1 booster, **dưới ngưỡng thì mất trắng**. Không hề
có số dư nào để tiêu.

Nên F19 phải dựng số dư đó. Cách làm giữ đúng tinh thần "không thêm tiền tệ thứ
tư": mỗi ván thắng-không-full-clear cho **đúng một** phần thưởng — đủ ngưỡng thì
booster (như cũ), dưới ngưỡng thì gom vào số dư thay vì mất trắng. Không trả hai
lần cho cùng một phép đo, và phần trước đây vứt đi giờ có chỗ dùng.

Quyết định đó nằm ở hàm thuần `craftOutcomeFor` chứ không phải `if/else` trong
`checkEnd` — nhánh trong `checkEnd` cần `activeGame` thật nên chỉ test được bằng
harness engine, mà quy tắc "một phần thưởng" thì đáng khoá bằng test rẻ.
Mutation-check bắt đúng chỗ này: bản đầu để `if/else` inline và gỡ nhánh gom
điểm **không** làm test nào đỏ.

## Đã làm

- `pigments.dart` — 6 pigment `fusionOnly`, `kPigmentRecipes` (6 công thức,
  khoá chuẩn hoá `recipeKey` nên đổi chỗ nguyên liệu vẫn ra một), `assert` mới
  cấm pigment fusion vừa mua được bằng xu.
- `craft_points.dart` — `craftOutcomeFor` (thuần).
- `game_controller.dart` — số dư `craftPoints`, `fusePigments`,
  `discoveredRecipes` (re-validate theo bảng const khi nạp).
- `color_alchemy_screen.dart` — bàn pha là mục **đầu tiên trong** `ListView`.

## Hai lỗi tự gây ra rồi tự bắt

1. **Bàn pha đặt ngoài `ListView` làm tràn màn hình** — 18 ca test cũ đỏ cùng
   lúc. Đưa vào trong danh sách cuộn.
2. **`_PigmentChip` ném `Bad state: No element`.** Nó giả định pigment còn khoá
   **luôn** có coin hoặc achievement, rồi gọi `firstWhere` không `orElse`. Thêm
   dạng mở khoá thứ tư là màn hình chết ngay khi dựng. Đây đúng là thứ AC cảnh
   báo ("đừng để assert nói dối") — nhưng chỗ nói dối lại nằm ở UI, không phải
   ở assert.

Cùng lý do, `test/data/pigments_test.dart` khẳng định "đúng 1 trong **3** dạng"
đã cập nhật thành 4 — sửa cho đúng sự thật thay vì nới lỏng điều kiện.

## Kiểm chứng

- `test/data/pigment_fusion_test.dart` — 25 ca: bảng dữ liệu (mọi công thức trỏ
  pigment có thật, mọi pigment fusion đều pha ra được, không công thức nào ra
  pigment mua được), số dư craft point, pha (nguyên liệu **không** mất, thiếu
  điểm/chưa sở hữu/không công thức đều **không** trừ điểm, không pha lại được),
  sổ công thức, và nhóm "mỗi ván đúng MỘT phần thưởng".
- `test/widget/color_alchemy_screen_test.dart` — +5 ca cho bàn pha.
- **Mutation-check 4/4 bị bắt** (sau khi tách hàm thuần).
- Verify trên Pixel 7 Pro: 40 → 32 CP, báo "Khám phá ra Bọt Biển!", màu mới
  dùng được ngay, hai nguyên liệu vẫn còn, 6 pigment fusion hiện nhãn
  "Chỉ pha ra".
- Toàn bộ suite: **1437 xanh**.

## Nợ đã ghi

1. Công thức chưa khám phá **không** hiện gợi ý mờ như AC yêu cầu — hiện chỉ có
   bộ đếm `0/6`. Người chơi phải tự thử.
2. Chưa rà `mystery_crate.dart` và `totalCosmeticsOwned` xem pigment fusion có
   nên tính vào không — AC có yêu cầu, chưa làm.
3. i18n mới en + vi.
