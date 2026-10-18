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
- [x] **Unit test**: Validate streak/shield count không âm, title/action labels không rỗng (`streak_shield_card_test.dart`, 9 test pass).
- [x] **Widget test**: Hiển thị streak/shields; Use Shield và Repair gọi đúng callback; nhánh hết shield, semantics; Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) mở card, dùng shield, xác nhận callback đổi state và repair seam khi shield bằng 0. Smoke chỉ dùng showcase in-memory, không ghi inventory hoặc gọi `DailyLoginService` thật.
- [x] **Golden test**: `runGoldenMatrix` có shield/hết shield trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: Unmount dialog giữa entrance không ném lỗi hoặc gọi action.
- [x] **Network conditioning test**: N/A với widget thuần presentation; backend streak restore thuộc consumer.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-144.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming (p50/p95/p99, slow-frame %, jank count).
- [x] **IAP & Ad mediation test**: N/A — repair callback là seam; package không mở purchase/ad SDK.

## Hiệu năng & Animation
- [x] Không có animation/controller nội bộ; NeonDialog entrance tuân Reduced Motion.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
