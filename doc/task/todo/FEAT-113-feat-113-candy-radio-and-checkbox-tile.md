---
id: FEAT-113
title: CandyRadioGroup & CandyCheckboxTile — Lựa chọn radio và hộp kiểm bo nảy
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Thư viện hiện chỉ có ToggleSwitch, thiếu hoàn toàn Radio button và Checkbox cho các form cài đặt, chọn chế độ chơi, danh sách tuỳ chọn app.

## Đề xuất phạm vi
Cung cấp CandyRadioGroup<T> và CandyCheckboxTile phong cách kẹo bo tròn, viền đậm, dấu tích/chấm tròn nảy đàn hồi (scale bounce) khi được chọn.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra radio group đổi giá trị đúng và checkbox tile toggle boolean giá trị chính xác.
- [ ] **Widget test**: Tap vào checkbox tile, kiểm tra checkmark xuất hiện kèm animation nảy nhẹ và gọi onChanged đúng giá trị.
- [ ] **Integration test**: Chọn các tuỳ chọn cài đặt bằng CandyRadio trên thiết bị thật, kiểm tra độ nhạy cảm ứng.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tối ưu Semantics chuẩn trợ năng (hasFlag isSelected/isChecked), zero layout shift.
