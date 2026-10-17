---
id: FEAT-130
title: SeasonEventBanner — Banner sự kiện mùa kèm đếm ngược và thanh tiến độ
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 7)
---

## Vì sao cần
`SeasonEventService` đã theo dõi cửa sổ thời gian của sự kiện live-ops nhưng chưa có thành phần giao diện đi kèm. Banner sự kiện (Halloween, Tết, mùa hè) với đếm ngược ngày giờ còn lại và thanh tiến độ mốc thưởng là điểm vào chính dẫn người chơi tới nội dung live-ops.

## Đề xuất phạm vi
Widget `SeasonEventBanner` hiển thị:
- Tiêu đề sự kiện, mô tả ngắn, icon/hình nền theo màu chủ đề của sự kiện.
- Đếm ngược thời gian còn lại, dùng `fmtDurLong` và chuyển sang dạng ngày khi còn hơn 24 giờ.
- Thanh tiến độ tới mốc thưởng kế tiếp (`progress` 0.0..1.0) và nhãn mốc hiện tại.
- Khi sự kiện kết thúc: giữ banner, đổi sang trạng thái "Ended", khoá nút vào sự kiện và gọi `onEnded` đúng một lần.
- Widget thuần dữ liệu: caller đọc `SeasonEventService` rồi truyền `endsAt`, `progress`, `title`; callback `onTap` do caller sở hữu. Không phụ thuộc trực tiếp GetX service.
- Ranh giới với `FlashSaleOfferCard`: banner chỉ dẫn vào sự kiện, không có giá và không có nút mua.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra định dạng đếm ngược (ngày/giờ/phút), validate `progress` trong 0.0..1.0 và tiêu đề không rỗng.
- [ ] **Widget test**: Tap banner gọi `onTap`; hết giờ gọi `onEnded` đúng một lần và khoá tap; thanh tiến độ phản ánh `progress`; Reduced Motion; semantics đọc đúng tên sự kiện và thời gian còn lại.
- [ ] **Showcase test**: Tích hợp vào showcase với nút tăng tiến độ, cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap trên thiết bị vật lý thật, không dùng simulator.

## Hiệu năng & Animation
- [ ] Timer đếm ngược huỷ khi hết giờ hoặc unmount; không rebuild toàn bộ banner mỗi giây ngoài vùng chữ đếm ngược.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
