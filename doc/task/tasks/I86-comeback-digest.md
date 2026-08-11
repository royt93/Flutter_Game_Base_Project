# I86 — Comeback bonus kèm digest "bạn đã bỏ lỡ gì"

**Epic:** E8 Enhance · **SP:** 3 · **Pri:** Could
**Deps:** [[I84]] nên làm trước (dùng chung hàm xếp hạng)
**Mở rộng:** [[I10]] · **Liên quan:** [[I72]]
**Trạng thái:** 📋 To Do

## Hiện trạng
`checkComebackBonus()` (`game_controller.dart:1696-1709`): vắng ≥3 ngày →
+300 coin, +1 bomb, +1 shuffle. Popup hiện số coin. Hết.

Đây là popup thưởng trơ — không nói gì về việc **vì sao đáng quay lại**.

## Đề xuất
Kèm theo thưởng, hiện một digest ngắn dựng từ dữ liệu **đã có sẵn trong máy**
(không network, không AI):

- "Trong lúc bạn vắng: {N} ngày, {M} thử thách hằng ngày đã trôi qua"
- "Bạn còn {K} sao nữa là mở rương Star Road tiếp theo"
- "Mục tiêu tuần này còn {X}/300 gem"
- "{Tên} đang là level nổi bật của tuần"
- "Mùa hiện tại còn {D} ngày"

Chọn 2-3 dòng liên quan nhất, không đổ hết.

## Vì sao Could
Đây là polish, không phải cơ chế. Giá trị thật nằm ở việc chuyển popup từ
"đây, cầm tiền" sang "đây là lý do chơi tiếp" — nhưng nếu [[I84]] đã làm
xong, phần lớn tác động đó đã đạt được ở Home rồi.

Xếp Could có chủ ý: làm nếu còn chỗ, bỏ nếu không.

## User story
*As a* người chơi quay lại sau một tuần *I want* biết ngay mình đang ở đâu và
gần đạt gì *so that* tôi có lý do chơi ván tiếp theo, không chỉ nhận coin rồi
đóng app.

## Acceptance criteria
- [ ] Popup comeback hiện thưởng (như cũ) **+** 2-3 dòng digest.
- [ ] Digest dựng bằng hàm **thuần** trong `lib/logic/` — nhận state làm tham
      số, không đọc `StorageService`, không `Get.find`. Test được không cần
      widget.
- [ ] Chỉ hiện dòng **đúng và có ý nghĩa**: không nói "còn 5 sao nữa" nếu
      rương đó đã nhận; không nhắc mùa nếu mùa vừa reset.
- [ ] Không có dòng nào hợp lệ → chỉ hiện thưởng như cũ, **không** hiện khung
      digest rỗng.
- [ ] Số ngày vắng lấy từ `todayEpochDay()` (đã kẹp chống chỉnh đồng hồ),
      **không** `DateTime.now()` thô.
- [ ] i18n 22 ngôn ngữ, có xử lý số nhiều đúng ngữ pháp từng ngôn ngữ (hoặc
      chọn cách diễn đạt không phụ thuộc số nhiều — rẻ hơn nhiều).
- [ ] Test thuần cho hàm dựng digest.

## Subtask
1. `lib/logic/comeback_digest.dart` — hàm thuần trả `List<String>` (key i18n
   + tham số), tối đa 3 dòng.
2. Nếu [[I84]] đã làm: **tái dùng** `rankNextActions` thay vì viết logic xếp
   hạng thứ hai. Digest ≈ "3 next action hàng đầu, diễn đạt ở thì quá khứ".
   Đây là lý do I84 nên đi trước.
3. Nối vào popup comeback ở `home_screen.dart`.
4. i18n + test.

## Ghi chú
`milestone_journal.dart` đã là hàm thuần gom mốc theo thời gian — đọc nó
trước, có thể phần lớn dữ liệu digest cần đã nằm sẵn ở đó.

Đừng viết văn cảm xúc do máy sinh ("chúng tôi nhớ bạn!"). Câu số liệu cụ thể
("còn 2 sao nữa là mở rương") có tác dụng hơn nhiều và không bao giờ nghe
sáo rỗng.

DoD chung: `../README.md`.
