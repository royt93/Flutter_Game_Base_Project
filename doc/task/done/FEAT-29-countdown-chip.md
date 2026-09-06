---
id: FEAT-29
title: CountdownChip/TimerBadge — chip tự đếm ngược live
type: feature
priority: P2
effort: S
source: user pick (vòng audit cuối cùng, chốt)
---

## Vì sao cần
Không có widget nào hiện tại tự bind 1 `Ticker`/`Timer.periodic` với `fmtDur`
để hiển thị đếm ngược live — mỗi màn hình cần (Energy full trong FEAT-08, sale
countdown trên `ShopItemCard` FEAT-25, daily reward reset trong FEAT-07) phải
tự viết `Timer.periodic` + `setState` riêng lẻ.

## Đề xuất phạm vi
`CountdownChip`: nhận `DateTime target` (hoặc `Duration remaining` + mốc bắt
đầu), tự chạy timer nội bộ update mỗi giây, hiển thị `fmtDur` (dùng lại hàm
có sẵn, không viết lại logic format), tự dừng + gọi `onDone` khi về 0, tự
huỷ timer khi unmount.

## Yêu cầu test
- **Unit test**: không áp dụng riêng (logic format đã có test ở `format_test.dart`) — chỉ cần verify widget gọi đúng `fmtDur`.
- **Widget test**: dựng với `target` trong tương lai gần, `pump(Duration(seconds: 1))` vài lần, assert text hiển thị giảm đúng; verify `onDone` được gọi đúng 1 lần khi về 0, không gọi lặp lại sau đó; verify `Timer` bị huỷ khi widget unmount giữa chừng (không lỗi `setState after dispose`).
- **Integration test**: demo `CountdownChip` chạy thật trong 1 màn hình `example/integration_test/`, để chạy đủ vài giây thật, verify không leak/không lỗi trên thiết bị thật.

## Demo
Section "Countdown Chip" trong `WidgetShowcaseScreen` với 1 target 15 giây kể từ lúc mount để xem chạy thật.

## Acceptance criteria
- [ ] Unmount giữa chừng không gây lỗi `setState after dispose`.
- [ ] Đủ 3 loại test + demo trong showcase.
