---
id: FEAT-171
title: ProfileStatsCard — Thẻ hồ sơ người chơi với avatar, danh hiệu và chỉ số chính
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Màn hồ sơ cần một thẻ tổng hợp: avatar trong khung, tên, danh hiệu, cấp độ và vài chỉ số chính (số ván thắng, streak cao nhất, tổng thời gian chơi). Đây là phần ghép của `AvatarFrame`, `XpLevelHeader` và dữ liệu do caller cung cấp, tránh mỗi game tự dựng lại.

## Đề xuất phạm vi
Widget `ProfileStatsCard` hiển thị:
- Avatar trong `AvatarFrame` (`avatar`, `frameColor`), `name`, `title?`, `level?`.
- 2–4 ô chỉ số `ProfileStat(label, valueText, icon?)` do caller định dạng sẵn (vd `1.2K`, `3h 20m`); bố cục lưới tự xuống dòng khi chữ lớn.
- `onTap()` tuỳ chọn mở màn hồ sơ đầy đủ; `onEditAvatar()` tuỳ chọn hiện nút sửa 48dp trên avatar.
- Tên và danh hiệu dài cắt ellipsis; không tràn ở 320dp + textScale 2.0.
- Presentation-only: caller sở hữu dữ liệu, định dạng số, lưu và mở màn khác.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `name` không rỗng, số chỉ số trong 0..4, label/valueText không rỗng; `ArgumentError` runtime.
- [ ] **Widget test**: đủ thông tin, thiếu title/level, 0/2/4 chỉ số, tap thẻ, tap sửa avatar (không kích hoạt tap thẻ), semantics đọc tên + danh hiệu + chỉ số, tên rất dài, 320dp + textScale 2.0 gutter 16dp, RTL thật, target >= 48dp.
- [ ] **Integration test (Device)**: tap thẻ và tap sửa avatar qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground, hỏi nếu đang là app khác; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` đủ/tối thiểu/4 chỉ số/tên dài × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1 theo CLAUDE.md.
- [ ] **Interruption test**: đổi chỉ số và tên liên tục rồi unmount không crash, giá trị cuối đúng.
- [ ] **Network conditioning test**: N/A — avatar do caller cấp, thẻ không tải ảnh.
- [ ] **Memory leak & profiling test**: không còn ticker/controller sau unmount và khi reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi cập nhật chỉ số liên tục và khi cuộn danh sách 50 thẻ (profile thiết bị thật), ghi rõ giới hạn engine timing.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Chỉ số đổi giá trị có chuyển động ngắn (không khi mount); `reducedMotion` đổi tức thì; tái dùng `PressableScale`, không tạo controller riêng.
