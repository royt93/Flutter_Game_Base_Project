# I84 — Home gợi ý "làm gì tiếp theo" thay vì liệt kê 14 mode

**Epic:** E8 Enhance · **SP:** 5 · **Pri:** Must
**Deps:** — · **Liên quan:** [[X14]] [[X9]] [[I85]]
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
Game có 14 `GameMode` + ~20 hệ meta (prestige, achievements, daily quests,
weekly goal, clan, season pass, pets, pigments, constellations, sticker album,
login streak, spin wheel, daily reward, comeback bonus, treasure map, raid
boss, 4 hệ cosmetic…). `HomeScreenController.buildHomeCards` **liệt kê**
chúng thành carousel — không xếp hạng, không lọc, không gợi ý.

Kết quả: người chơi mở app và phải tự trả lời "hôm nay tôi nên làm gì?" từ
một danh sách 20 mục mà phần lớn đang ở trạng thái "chưa có gì để làm".

Đây là điểm yếu được **cả 3 vòng audit độc lập** nêu ra.

## Vì sao Must
Đây là đòn bẩy retention lớn nhất trong Round 9 mà không cần thêm nội dung
mới. Toàn bộ nội dung đã tồn tại — vấn đề thuần tuý là **trình bày**. Chi
phí thấp, tác động cao, không rủi ro cân bằng gameplay.

Với người chơi cũ: nhắc đúng thứ sắp hết hạn (quest hôm nay, goal tuần, raid
cuối tuần) là lý do quay lại. Với người chơi mới: che bớt 18 hệ chưa mở khoá
là cách duy nhất để họ không bỏ chạy.

## User story
*As a* người chơi mở app *I want* thấy ngay 1-3 việc đáng làm nhất lúc này
*so that* tôi không phải quét qua 20 thẻ để quyết định.

## Acceptance criteria
- [ ] Home có khu vực "Tiếp theo" ở **trên cùng**, hiện tối đa **3** gợi ý,
      mỗi gợi ý là 1 nút bấm đi thẳng tới chỗ cần đến.
- [ ] Xếp hạng theo quy tắc **thuần, test được** (hàm không đụng GetX/storage,
      nhận state làm tham số) — đặt ở `lib/logic/next_action.dart`.
- [ ] Ưu tiên theo thứ tự: (1) thứ **sắp hết hạn** và còn nhận được — daily
      reward, spin, daily quest gần xong, raid cuối tuần ngày cuối; (2) thứ
      **đã đủ điều kiện nhận mà chưa nhận** — chest star road, mốc season,
      weekly goal, clan pool, achievement; (3) tiến độ campaign kế tiếp.
- [ ] Không bao giờ gợi ý thứ người chơi **chưa mở khoá** hoặc **đã hoàn
      thành hôm nay**.
- [ ] Người chơi mới (level 1-5): chỉ hiện gợi ý campaign + daily reward.
      Toàn bộ mode phụ và hệ meta bị **ẩn** khỏi khu vực này cho tới khi mở
      khoá — carousel đầy đủ vẫn ở dưới cho ai muốn khám phá.
- [ ] Không có gợi ý nào hợp lệ → hiện 1 dòng thân thiện, **không** để khu
      vực trống hay hiện thẻ giả.
- [ ] Chuỗi mới thêm đủ 22 ngôn ngữ (`app_translations_test.dart` cưỡng chế).
- [ ] Test: `test/logic/next_action_test.dart` cho hàm xếp hạng thuần +
      cập nhật `home_screen_test.dart`.

## Subtask
1. `lib/logic/next_action.dart` — `List<NextAction> rankNextActions({...})`
   thuần, nhận mọi state cần thiết làm tham số. Không đọc `StorageService`,
   không `Get.find`. Trả tối đa 3.
2. `home_screen_controller.dart` — gom state, gọi hàm trên, phơi ra `Rx`.
   Refresh khi resume (hook đã có sẵn).
3. `home_screen.dart` — dựng khu vực "Tiếp theo" trên carousel hiện có.
   **Tái dùng** `home_carousel.dart` / `NeonButton` / `CoinChip`, không tạo
   widget mới nếu tránh được.
4. i18n: thêm key vào map tiếng Anh trước, rồi 21 map còn lại.
5. Test theo AC.

## Ghi chú kỹ thuật
Đừng xây "hệ thống gợi ý" có cấu hình/trọng số/tuning. Một hàm trả về danh
sách theo thứ tự if-else là đủ và dễ đọc hơn nhiều lúc 3 giờ sáng. Nếu sau
này cần tinh chỉnh, sửa thứ tự các `if` — đó là toàn bộ "tuning" cần thiết.

Không đụng carousel hiện có ([[X14]] vừa hợp nhất nó xong) — thêm phía trên,
không thay thế.

DoD chung: `../README.md`.

## Đã làm

`lib/logic/next_action.dart` (thuần) + `GameController.nextActions()` /
`_questsReadyToClaim()`, widget `lib/presentation/widgets/next_up_bar.dart`
(`Key('next_up_<kind>')`, `next_up_empty`), gắn lên đầu Home kèm router
`_onNextAction`.

Home phải bọc `LayoutBuilder + SingleChildScrollView + ConstrainedBox +
IntrinsicHeight`: đo trước khi thêm cho thấy Home vốn vừa khít **không dư một
pixel**, nên mọi thứ thêm vào đều tràn 110px.

## Kiểm chứng

- `test/logic/next_action_test.dart` — 16 ca (thuần, không đọc storage/GetX).
- `test/presentation/next_actions_wiring_test.dart` — 9 ca nối controller.
- `test/widget/next_up_bar_test.dart` — 8 ca hiển thị.
