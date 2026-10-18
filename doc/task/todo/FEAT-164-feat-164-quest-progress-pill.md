---
id: FEAT-164
title: QuestProgressPill — Viên nang tiến độ nhiệm vụ ngày kèm badge nhận thưởng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`QuestBoardPanel` là panel đầy đủ, quá lớn cho HUD màn hình chính. Cần một lối vào gọn cho biết "đã xong X/Y nhiệm vụ" và có phần thưởng chờ nhận hay chưa, để người chơi quay lại mở bảng nhiệm vụ.

## Đề xuất phạm vi
Widget `QuestProgressPill` hiển thị:
- `completed`/`total` (vd `2/3`) kèm vòng/thanh tiến độ nhỏ.
- `claimableCount`: badge số phần thưởng chờ nhận, ẩn khi 0, `9+` khi vượt 9 (tái dùng `BadgeDot`/mẫu badge của `ClanChatPreviewBar`, không viết lại animation).
- `onTap()` mở `QuestBoardPanel` do caller sở hữu.
- Trạng thái hoàn tất toàn bộ (`completed == total`) đổi sang màu/biểu tượng hoàn thành.
- Presentation-only: caller đọc `DailyQuestService`, widget không truy cập service.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `total > 0`, `0 <= completed <= total`, `claimableCount >= 0`, `claimableCount <= completed`; `ArgumentError` bằng kiểm tra runtime, không chỉ assert.
- [ ] **Widget test**: 0/total, giữa chừng, đủ, badge 0/1/9/10, tap, semantics đọc đủ tiến độ và số chờ nhận, 320dp + textScale 2.0 với gutter 16dp, RTL thật (kiểm tra `Directionality`).
- [ ] **Integration test (Device)**: tap pill mở overlay bảng nhiệm vụ qua caller seam trên thiết bị thật đang kết nối (kiểm tra lại serial và app foreground trước khi chạy); không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` các trạng thái 0/giữa/đủ/có badge × baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844. Baseline phải sinh bằng Linux + Flutter 3.35.1 (workflow `regenerate-goldens.yml`), không dùng ảnh macOS.
- [ ] **Interruption test**: cập nhật `completed` liên tục không để lại ticker/animation mồ côi sau unmount.
- [ ] **Network conditioning test**: N/A — caller sở hữu dữ liệu.
- [ ] **Memory leak & profiling test**: kiểm tra `transientCallbackCount == 0` sau unmount và reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi tiến độ đổi liên tục (profile, thiết bị thật); ghi rõ đây là engine timing, không chứng minh 60 FPS bền vững.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Số/tiến độ đổi có chuyển động ngắn; `reducedMotion` đổi tức thì, không tạo controller mới khi không cần.
