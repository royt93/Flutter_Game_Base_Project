---
id: FEAT-141
title: PrestigeConfirmationCard — Card xác nhận prestige và hệ số vĩnh viễn
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention, Monetization & Meta-Game UI (Wave 10)
---

## Vì sao cần
Prestige là thao tác reset tiến trình ngắn hạn để nhận multiplier vĩnh viễn. Đây là quyết định có hậu quả lớn và khó đảo ngược; người chơi cần thấy rõ điều sẽ mất, multiplier sẽ tăng bao nhiêu và phần thưởng mở khóa trước khi xác nhận.

## Đề xuất phạm vi
Widget `PrestigeConfirmationCard` hiển thị:
- Level/score hiện tại sẽ reset và giá trị yêu cầu prestige.
- Multiplier hiện tại so với multiplier sau prestige (`currentMultiplier`, `nextMultiplier`) và chênh lệch.
- Danh sách phần thưởng vĩnh viễn caller cung cấp (`PrestigeReward`: icon, label, amount).
- Hai action rõ ràng: `Prestige` gọi `onConfirm`, `Keep Playing` gọi `onCancel`; widget không tự reset save.
- Static `.show(context, ...)` qua `NeonDialog.show` in-tree-safe.
- Presentation-only: caller gọi `PrestigeService.prestige()` sau khi nhận confirm và chịu trách nhiệm commit/reset transaction.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate current level, threshold, multiplier hữu hạn/dương, next > current, rewards không rỗng, title/labels không rỗng (`test/widget/common/prestige_confirmation_card_test.dart`, 14 test pass).
- [x] **Widget test**: So sánh multiplier hiện tại/sau prestige, threshold và rewards; confirm/cancel callback tách biệt; dismiss qua `.show`; Reduced Motion render; semantics nêu level reset, threshold và multiplier mới.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) pass: mở card, Keep Playing tăng cancel counter, Prestige Now tăng confirm counter. Caller seam là counter showcase, chưa có fake `PrestigeService`.
- [x] **Golden test**: `runGoldenMatrix` baseline/dark/vi/RTL/textScale/reducedMotion pass (`prestige_confirmation_card_golden_test.dart`).
- [x] **Interruption test**: unmount giữa entrance không gọi callback; paused/resumed không tự confirm. Chưa test "confirm đang chờ" qua background thật.
- [x] **Network conditioning test**: N/A — widget thuần presentation, không gọi backend.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-141.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming (p50/p95/p99, slow-frame %, jank count).
- [x] **IAP & Ad mediation test**: N/A — prestige xác nhận không tự mua hàng/hiển thị ad.

## Hiệu năng & Animation
- [x] `RepaintBoundary` bọc thanh so sánh multiplier. Widget không tự có animation; entrance do `NeonDialog` quyết định và đã tôn trọng Reduced Motion.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.

## Phạm vi đã chốt
- [x] Ngưỡng prestige: `requiredPrestigeValue` là `String` đã format sẵn, caller quyết định level hay score (user chọn phương án này).
- [x] `onCancel` bắt buộc, widget không tự reset save.
- [x] `PrestigeReward` là model thuần trình bày (user chọn).

## Việc còn mở
- MemoryWatchdog và FrameTiming chưa chạy cho FEAT-141, không tuyên bố đạt 60 FPS.
