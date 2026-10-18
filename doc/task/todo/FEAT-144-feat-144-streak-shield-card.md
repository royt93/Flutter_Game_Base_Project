---
id: FEAT-144
title: StreakShieldCard — Thẻ bảo vệ chuỗi đăng nhập bằng shield
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Live-Ops, Retention & VIP Meta-Game UI (Wave 11)
---

## Vì sao cần
Người chơi có thể mất chuỗi đăng nhập vì bỏ lỡ một ngày. Thẻ cần cho thấy trạng thái chuỗi, shield còn lại và hậu quả trước khi caller quyết định dùng shield hoặc sửa streak.

## Đề xuất phạm vi
Widget `StreakShieldCard` hiển thị:
- Streak hiện tại, ngày bị bỏ lỡ (caller cung cấp), số shield còn lại và trạng thái có thể bảo vệ hay không.
- Nút `Use Shield` gọi `onUseShield`; tùy chọn action phục hồi gọi `onRepair` do caller cung cấp, không mở shop/IAP/ads bên trong widget.
- Nút hành động bị disable khi không đủ shield hoặc streak không thể phục hồi theo props.
- Static `.show(context, ...)` qua `NeonDialog.show` in-tree/Flame-safe.
- Presentation-only: caller tích hợp `DailyLoginService`/`StreakRepairDialog` và chịu trách nhiệm cập nhật streak, inventory, transaction.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate streak/shield count không âm, title/action labels không rỗng.
- [ ] **Widget test**: Hiển thị streak/shields; Use Shield và Repair gọi đúng callback; disable theo trạng thái; semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro kiểm tra preview, shield action và caller-owned state; không dùng simulator.
- [ ] **Golden test**: Có shield, hết shield, không thể repair trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Pause/resume hoặc dismiss trong confirm không gọi action hai lần.
- [ ] **Network conditioning test**: N/A với widget thuần presentation; backend streak restore thuộc consumer.
- [ ] **Memory leak & profiling test**: MemoryWatchdog xác nhận overlay/dialog dispose sau dismiss.
- [ ] **Frame rate / Jank test**: FrameTiming entrance/dismiss; báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — repair callback là seam; package không mở purchase/ad SDK.

## Hiệu năng & Animation
- [ ] Animation trang trí ngắn, không có controller nếu badge tĩnh đủ dùng; Reduced Motion bỏ entrance/shine.
- [ ] Sustained 60 FPS benchmark: chỉ ghi khi đo workload trên thiết bị vật lý.
