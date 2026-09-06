---
id: ENH-11
title: fmtNum thêm chế độ rút gọn K/M/B cho số lớn (idle game scale)
type: enhance
priority: P1
effort: M
source: user pick (chốt trong phiên chọn util mới) + agy đã gợi ý trước đó
---

## Hiện trạng
`fmtNum` (`lib/core/utils/format.dart`) hiện chỉ thêm dấu phân cách hàng nghìn
theo locale — không có chế độ rút gọn kiểu `1.5K`, `2.4M`, `10.8B` thường thấy
ở game idle/tycoon khi số dư vượt quá vài triệu.

## Đề xuất
Thêm 1 hàm mới `fmtNumCompact(num n)` (giữ nguyên `fmtNum` hiện có + test của
nó không đổi — tránh phá vỡ contract đang có, giống cách tiếp cận ở ENH-02):
ngưỡng rút gọn K (>=1,000), M (>=1,000,000), B (>=1,000,000,000), T
(>=10^12) nếu cần, giữ 1 chữ số thập phân (`1.5K` chứ không `1.500K`).

## Yêu cầu test
- **Unit test**: bảng test đủ mốc ngưỡng (999 → không rút gọn, 1_000 → "1K",
  1_500_000 → "1.5M", 999_999_999_999 → giá trị đúng ở biên T), số âm, số 0.

## Demo
Cập nhật demo `CurrencyCounter` trong `WidgetShowcaseScreen` với 1 case giá
trị lớn (vd 12_345_678) để thấy rõ khác biệt trước/sau.

## Acceptance criteria
- [ ] `fmtNum` hiện tại và test của nó không đổi hành vi.
- [ ] `fmtNumCompact` có test đủ các mốc ngưỡng, không lỗi làm tròn hiển thị (vd không ra "1.0K" mà phải là "1K").
