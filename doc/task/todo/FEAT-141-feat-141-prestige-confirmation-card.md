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
- [ ] **Unit test**: Validate multiplier hữu hạn/dương, next > current, danh sách reward không rỗng, title/labels không rỗng.
- [ ] **Widget test**: So sánh multiplier hiện tại/sau prestige và rewards; confirm/cancel callback tách biệt; dismiss chỉ sau callback đúng; Reduced Motion; semantics thông báo rõ save sẽ reset và multiplier mới.
- [ ] **Integration test (Device)**: Pixel 7 Pro xác nhận card hiển thị preview, cancel không gọi prestige; confirm gọi caller seam/fake service đúng một lần.
- [ ] **Golden test**: Golden matrix light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Background hoặc đóng dialog giữa entrance/confirm không double-call prestige và không mất confirm đang chờ.
- [ ] **Network conditioning test**: N/A nếu `PrestigeService` local; nếu consumer gọi backend, service/consumer contract test riêng với timeout/failure và không làm UI cấp thưởng giả.
- [ ] **Memory leak & profiling test**: MemoryWatchdog xác nhận dialog animation/overlay dispose sau cancel/confirm.
- [ ] **Frame rate / Jank test**: FrameTiming workload entrance/confirm, báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — prestige xác nhận không tự mua hàng/hiển thị ad.

## Hiệu năng & Animation
- [ ] `RepaintBoundary` cô lập badge; animation chỉ tồn tại khi dialog mount, Reduced Motion bỏ entrance/shine.
- [ ] Sustained 60 FPS benchmark: đo theo workload định sẵn nếu cần.
