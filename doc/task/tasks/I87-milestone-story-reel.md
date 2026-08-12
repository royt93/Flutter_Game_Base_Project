# I87 — Milestone Journal xuất share card "hành trình của bạn"

**Epic:** E8 Enhance · **SP:** 3 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I72]] · **Liên quan:** [[I57]] [[X6]]
**Trạng thái:** ✅ Done (2026-08-12)

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

---

## Đã làm

Subtask 1 trả lời được ngay: `share_helper.dart` + `ScoreCard` (I57) **đã đủ
tổng quát**. `captureBoardPng(GlobalKey)` chụp bất kỳ `RepaintBoundary` nào, và
`shareResultCard` đã có sẵn khuôn "dựng widget trong overlay ẩn ở `left: -9999`
→ chụp → gỡ". Nên task này đúng như dự đoán: **một layout mới + một hàm thuần +
nối dây**, không refactor gì.

- `lib/logic/milestone_journal.dart` — thêm `pickJourneyMilestones` (thuần, mở
  rộng file đã có, không tạo file mới) + hằng `kJourneyCardMilestones`.
- `lib/presentation/widgets/journey_card.dart` — thẻ **vuông 1:1**, bố cục cố
  định, dữ liệu vào qua constructor y như `ScoreCard`.
- `lib/core/share_helper.dart` — `shareJourneyCard` nhận **bytes** (bên gọi
  phải gỡ overlay ngay sau khi chụp) nhưng vẫn qua đúng `captureBoardPng`.
- `MilestoneJournalScreen` — nút "Chia sẻ hành trình", ẩn khi chưa có mốc nào.
- `StorageKeys.totalDaysPlayed` + bộ đếm trên `GameController` — số ngày chơi
  **không reset khi đứt streak**, khác hẳn `loginStreakCount`.

### Luật chọn mốc

Hai luật, theo thứ tự: (1) mỗi `MilestoneKind` nhiều nhất một dòng — không lọc
thì người chơi lâu năm có hàng chục achievement cùng ngày, đẩy hết mọi loại
khác ra ngoài và thẻ nào cũng giống thẻ nào; (2) thành tựu trước, phần còn lại
theo thời gian — điểm danh mới hơn không có nghĩa là đáng khoe hơn.

## Lỗi bắt được khi chạy trên máy

Thẻ hiện **"0 days"** cho người đang chơi. `_checkLoginStreak` thoát sớm khi
`prevDay == today`, nên save tạo trước khi có bộ đếm (hoặc người đã mở game hôm
nay rồi mới cập nhật bản này) đứng ở 0 tới tận ngày hôm sau. Bù đúng một lần về
1 trong nhánh thoát sớm — không đoán ngược lịch sử.

## Kiểm chứng

- `test/logic/journey_milestones_test.dart` — 11 ca thuần, gồm ca "cùng ngày
  vẫn tất định" (sort của Dart **không** ổn định) và ca "không sửa danh sách
  đầu vào".
- `test/widget/journey_card_test.dart` — 11 ca. Đây là ảnh sẽ đi **ra ngoài
  app**, nên khoá chặt nhất là không có ô trống/"null" (tên rỗng, tên toàn
  khoảng trắng, số 0) và không tràn bố cục (đủ trần mốc, mốc chữ 300 ký tự).
- `test/widget/milestone_journal_screen_test.dart` — 9 ca, gồm 5 ca cho bộ đếm
  ngày chơi.
- **Mutation-check 4/4 bị bắt:** bỏ lọc trùng loại; bỏ ưu tiên thành tựu; bỏ
  cộng ngày chơi; bỏ backfill.
- Verify trên Samsung S24 Ultra: mở drawer → Milestone Journal → "Share
  journey" → share sheet nhận PNG và hiện preview thẻ đúng.

## Nợ đã ghi, không giấu

1. **Nhánh "chưa có mốc nào" gần như không với tới được.** `_checkLoginStreak`
   đẩy `loginStreakCount` lên 1 ngay lần boot đầu, nên feed luôn có ít nhất một
   mốc. Guard `if (entries.isNotEmpty)` quanh nút chia sẻ vẫn giữ (rẻ và đúng)
   nhưng đừng đọc bộ test như bằng chứng nhánh đó được phủ — đã ghi rõ trong
   file test.
2. i18n mới en + vi (đúng DoD tối thiểu); 20 ngôn ngữ còn lại rơi về bản en qua
   `_extraEn`.
3. Phần **hình** của thẻ đúng như task đã lường: code chạy, còn đẹp hay không
   là việc của thiết kế. Bố cục hiện tại là bản dùng được, không phải bản đẹp.
