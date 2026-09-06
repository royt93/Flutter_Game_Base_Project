---
id: FEAT-27
title: ShimmerPlaceholder — skeleton loading cho list/grid content
type: feature
priority: P2
effort: S
source: user pick (vòng đề xuất thêm widget, chốt)
---

## Vì sao cần
Khác `LoadingOverlay` (barrier toàn màn hình) — đây là placeholder tại chỗ
cho nội dung list/grid chưa tải xong (ví dụ shop item, level list khi chờ
cloud save FEAT-16 sync). Chưa có trong bộ 21+9 widget hiện tại.

## Đề xuất phạm vi
`ShimmerPlaceholder`: 1 khối bo góc màu `NeonTheme.cardAlt`, chạy animation
gradient quét ngang lặp lại (dùng `AnimatedBuilder` + `LinearGradient` xoay,
không cần thêm package `shimmer` — làm được bằng stdlib Flutter theo đúng
tinh thần "không thêm dependency cho việc vài dòng làm được").

## Yêu cầu test
- **Unit test**: không áp dụng.
- **Widget test**: dựng widget, verify animation chạy (frame sau khác frame trước), dispose đúng khi unmount giữa chừng animation.
- **Integration test**: demo dựng 1 list giả lập loading trong `example/integration_test/`, verify không leak qua nhiều lần mount/unmount nhanh (scroll list).

## Demo
Section "Shimmer Loading" trong `WidgetShowcaseScreen`.

## Acceptance criteria
- [ ] Không thêm dependency `shimmer` hay tương tự vào `pubspec.yaml`.
- [ ] Đủ 3 loại test + demo.
