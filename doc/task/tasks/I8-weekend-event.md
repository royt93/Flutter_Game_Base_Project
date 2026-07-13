# I8 — Weekend event (x2 coin)

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Could · **Deps:** none

## Mục tiêu
Cuối tuần (thứ 7-CN theo giờ máy), nhân đôi coin thưởng từ mọi nguồn (thắng
level, chest, spin nếu I7 đã có).

## Vì sao
Retention nhẹ, không cần nội dung mới — chỉ nhân hệ số theo điều kiện thời gian.

## Acceptance criteria
- [ ] Hàm thuần `isWeekendEvent(now)` xác định đang trong sự kiện.
- [ ] Mọi điểm cộng coin hiện có (checkEnd, claimDaily, chest, spin) nhân đôi
      khi `isWeekendEvent` true.
- [ ] Banner nhỏ trên Home báo "Cuối tuần x2 coin" khi đang hiệu lực.
- [ ] Unit test: `isWeekendEvent` đúng cho thứ 7/CN, sai ngày thường; hàm cộng
      coin nhân đúng hệ số.

## Subtasks (gợi ý file)
1. `lib/core/utils/format.dart` hoặc file mới `weekend_event.dart` (hàm thuần).
2. `lib/presentation/controllers/game_controller.dart`: áp hệ số tại các điểm
   cộng coin sẵn có.
3. `lib/presentation/screens/home_screen.dart`: banner khi hiệu lực.

## Ghi chú kỹ thuật
1 hàm thuần + áp dụng tại các điểm cộng coin sẵn có — không tạo hệ thống event
riêng.

DoD chung: `../README.md`.
