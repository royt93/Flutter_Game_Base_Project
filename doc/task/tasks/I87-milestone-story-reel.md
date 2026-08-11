# I87 — Milestone Journal xuất share card "hành trình của bạn"

**Epic:** E8 Enhance · **SP:** 3 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I72]] · **Liên quan:** [[I57]] [[X6]]
**Trạng thái:** 📋 To Do

## Hiện trạng
`milestone_journal.dart` gom mọi mốc có dấu thời gian rải rác trong
`GameController` thành một feed đã sắp xếp — hàm thuần, đã có test, đã có
màn hình (`milestone_journal_screen.dart`).

Dữ liệu đẹp, nhưng chỉ người chơi tự xem. Không có đường ra ngoài.

Game đã có: `share_helper.dart`, `score_card.dart` (thẻ điểm chia sẻ được,
I57), `qr_flutter`, `share_plus`. Toàn bộ hạ tầng đã sẵn.

## Đề xuất
Nút "Chia sẻ hành trình" ở `milestone_journal_screen` → sinh **một ảnh** tóm
tắt: tổng sao, level cao nhất, combo lớn nhất, số ngày chơi, 3-5 mốc đáng nhớ
nhất, mascot skin đang dùng.

## Vì sao Could
Vòng lan truyền duy nhất khả thi cho game không có backend. Nhưng tác động
không đo được (không có analytics), và giá trị hoàn toàn phụ thuộc vào thẻ
có **đẹp** hay không — mà đó là việc của thiết kế, không phải của code.

Xếp Could: làm khi có người làm được phần hình.

## User story
*As a* người chơi đã đi được xa *I want* khoe hành trình bằng một ảnh
*so that* bạn tôi thấy và tải game.

## Acceptance criteria
- [ ] Nút chia sẻ ở `milestone_journal_screen`.
- [ ] Ảnh sinh ra chứa: tổng sao, level cao nhất đạt, combo lớn nhất, số ngày
      chơi, tối đa 5 mốc, mascot skin đang dùng, tên game.
- [ ] Chọn mốc bằng hàm **thuần** trong `milestone_journal.dart` (mở rộng
      file đã có, không tạo file mới).
- [ ] Ảnh đọc được ở cả chế độ sáng lẫn tối, tỉ lệ hợp mạng xã hội
      (1:1 hoặc 9:16 — chốt 1 cái, đừng làm cả hai).
- [ ] Không chứa gì nhận dạng cá nhân ngoài `playerName` mà người chơi tự
      nhập. Tên rỗng → dùng nhãn chung, **không** để trống hay hiện "null".
- [ ] Tái dùng đường render của `score_card.dart` (I57) — **không** dựng
      pipeline xuất ảnh thứ hai.
- [ ] i18n 22 ngôn ngữ cho mọi nhãn trên thẻ.
- [ ] Test widget dựng thẻ + test thuần cho hàm chọn mốc.

## Subtask
1. Đọc `score_card.dart` + `share_helper.dart` — xác định đường tái dùng
   được. Nếu chúng đã tổng quát, task này gần như chỉ là một layout mới.
2. `milestone_journal.dart` — hàm chọn "5 mốc đáng nhớ nhất" (thuần).
3. Widget thẻ + nút chia sẻ.
4. i18n + test.

## Ghi chú kỹ thuật
`pop_star_game.dart:310` có sẵn một `ponytail:` comment về `toImage()` không
await được trong widget test — đọc nó trước khi làm phần xuất ảnh, cùng cạm
bẫy.

Nếu `score_card.dart` không tái dùng được mà không refactor lớn: **đóng task,
mở lại sau**. Không đáng dựng pipeline xuất ảnh thứ hai cho một tính năng
Could.

DoD chung: `../README.md`.
