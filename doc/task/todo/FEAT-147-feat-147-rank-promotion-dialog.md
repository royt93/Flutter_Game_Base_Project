---
id: FEAT-147
title: RankPromotionDialog — Dialog chúc mừng thăng hạng với huy hiệu và quà
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Live-Ops, Retention & VIP Meta-Game UI (Wave 11)
---

## Vì sao cần
Thăng hạng là khoảnh khắc thành tựu quan trọng trong game cạnh tranh. Dialog cần nhấn mạnh hạng cũ, hạng mới và quà thăng hạng, hoàn chỉnh với animation hào quang nhưng vẫn tôn trọng Reduced Motion.

## Đề xuất phạm vi
Widget `RankPromotionDialog` hiển thị:
- Hạng trước (`fromTier`) và hạng mới (`toTier`) bằng `LeaderboardTier` có sẵn, huy hiệu mới nổi bật với hào quang.
- Danh sách quà thăng hạng caller cung cấp (tái dùng `MilestoneReward`).
- Nút `Continue` gọi `onContinue`; tùy chọn `Share` gọi `onShare` do caller cung cấp.
- Static `.show(context, ...)` qua `NeonDialog.show` in-tree/Flame-safe.
- Presentation-only: caller tính hạng và cấp thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate toTier cao hơn fromTier, rewards không rỗng nếu được cung cấp, labels không rỗng.
- [ ] **Widget test**: Hiển thị hạng cũ/mới/rewards; Continue và Share đúng callback; Share chỉ hiện khi có `onShare`; semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở dialog, Continue/Share gọi caller seam; không dùng simulator.
- [ ] **Golden test**: Các cặp tier (bronze→silver, gold→diamond) trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Pause/resume hoặc dismiss giữa entrance; không gọi callback hai lần.
- [ ] **Network conditioning test**: N/A — widget thuần presentation.
- [ ] **Memory leak & profiling test**: MemoryWatchdog xác nhận controller hào quang dispose sau dismiss.
- [ ] **Frame rate / Jank test**: FrameTiming entrance + hào quang; báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — Share là callback caller sở hữu.

## Hiệu năng & Animation
- [ ] Hào quang dùng `SunburstGodRays` hiện có, `RepaintBoundary` cô lập; Reduced Motion bỏ vòng quay.
- [ ] Sustained 60 FPS benchmark: chỉ ghi khi đo workload trên thiết bị vật lý.
