# F19 — Pigment Fusion: pha 2 pigment ra pigment hiếm

**Epic:** E9 Tính năng mới · **SP:** 5 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I62]] · **Tái dùng:** [[I32]] craft points
**Trạng thái:** 📋 To Do

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
