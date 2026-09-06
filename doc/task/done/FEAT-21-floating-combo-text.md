---
id: FEAT-21
title: FloatingComboText — text "+10"/"Combo x3" bay lên rồi mờ dần tại chỗ
type: feature
priority: P2
effort: M
source: user pick (đã chốt trong phiên chọn widget mới)
---

## Vì sao cần
Feedback tức thời dạng text bay lên mờ dần (khác coin-fly FEAT-12 vốn bay tới
1 đích cụ thể — cái này chỉ pop tại chỗ) — hiệu ứng "game-feel" rẻ tiền nhưng
hiệu quả cao, hiện chưa có.

## Đề xuất phạm vi
`FloatingComboText`: nhận `text`, `color`, vị trí xuất hiện; tự chạy 1
animation (translate lên + fade out) rồi tự gọi callback `onDone`/tự remove
khỏi overlay — không cần quản lý state bên ngoài lâu dài (giống
`ToastBanner.show` ở cách dùng: gọi 1 lần, tự dọn).
Ghi chú: overlap 1 phần ý tưởng với IDEA-08 (Juice framework) — làm task này
trước, IDEA-08 sau này có thể tái dùng thay vì làm lại.

## Yêu cầu test
- **Unit test**: không áp dụng trực tiếp (thuần animation UI).
- **Widget test**: dựng `FloatingComboText`, `pump()` qua đúng duration cấu hình, assert widget tự remove khỏi tree sau khi animation xong (không leak `AnimationController`).
- **Integration test**: dựng demo trigger nhiều `FloatingComboText` liên tiếp nhanh trong `example/integration_test/`, verify không crash/không leak qua nhiều lần trigger trên thiết bị thật.

## Demo
Section "Combo Text" trong `WidgetShowcaseScreen` với nút trigger nhiều lần liên tiếp để test spam.

## Acceptance criteria
- [ ] Trigger liên tiếp nhanh (spam) không leak `AnimationController`/`OverlayEntry`.
- [ ] Đủ 3 loại test + demo trong showcase.
