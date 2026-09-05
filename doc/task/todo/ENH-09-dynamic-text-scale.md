---
id: ENH-09
title: Widget kit chưa được test với dynamic text scale (a11y font lớn)
type: enhance
priority: P2
effort: M
verified: true
source: Claude, phát hiện khi audit bổ sung
---

## Vấn đề
Các widget candy-style (`CommonButton`, `BadgeDot`, `IconBadgeButton`,
`ProgressBarStars`...) dùng kích thước cố định (`size`, `width`, `height`
constant) — chưa có test/golden nào dựng với `MediaQuery.textScaler` phóng to
(người dùng bật "cỡ chữ lớn" trong Settings hệ điều hành). Khả năng cao text
bị tràn/cắt ở các badge/button nhỏ.

## Đề xuất
Không cần sửa ngay toàn bộ — trước tiên thêm 1 golden test dựng
`WidgetShowcaseScreen` (hoặc 1 vài widget đại diện) với
`TextScaler.linear(1.5)`/`2.0`, xem widget nào vỡ layout trước, từ đó mới sửa
đúng chỗ cần.

## Acceptance criteria
- [ ] Có golden/test dựng với text scale lớn cho ít nhất `CommonButton`, `BadgeDot`, `IconBadgeButton`.
- [ ] Danh sách widget bị vỡ layout (nếu có) được ghi nhận thành task fix riêng.
