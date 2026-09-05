---
id: FEAT-28
title: PaginatedDotsIndicator — chấm trang cho carousel/onboarding nhiều bước
type: feature
priority: P2
effort: S
source: user pick (vòng đề xuất thêm widget, chốt)
---

## Vì sao cần
Đi cùng FEAT-11 (Onboarding spotlight overlay) nếu luồng onboarding thiết kế
nhiều bước thay vì 1 spotlight đơn — cần chấm trang chỉ vị trí hiện tại.
Chưa có trong bộ widget hiện tại.

## Đề xuất phạm vi
`PaginatedDotsIndicator`: nhận `count`, `currentIndex`, tự vẽ N chấm, chấm
hiện tại to/sáng hơn (dùng `NeonTheme` palette). Thuần trình bày, không tự
quản lý `PageController` (app tự nối qua `onPageChanged`).

## Yêu cầu test
- **Unit test**: không áp dụng.
- **Widget test**: đổi `currentIndex` qua `didUpdateWidget`, verify đúng chấm nào được highlight; golden test cho vài giá trị `count`/`currentIndex`.
- **Integration test**: demo nối với 1 `PageView` thật trong `example/integration_test/`, swipe qua các trang, verify indicator đổi đúng theo trang hiện tại trên thiết bị thật.

## Demo
Section "Page Dots" trong `WidgetShowcaseScreen`, nối với 1 `PageView` demo 3-4 trang.

## Phụ thuộc
Chỉ thật sự cần nếu FEAT-11 thiết kế onboarding nhiều bước — nếu FEAT-11 chỉ dùng 1 spotlight đơn, có thể hoãn.

## Acceptance criteria
- [ ] Đủ 3 loại test + demo.
