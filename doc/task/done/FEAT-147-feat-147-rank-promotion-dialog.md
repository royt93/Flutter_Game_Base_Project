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
- [x] **Unit test**: Validate toTier cao hơn fromTier, title/labels không rỗng (`rank_promotion_dialog_test.dart`, 9 test pass).
- [x] **Widget test**: Hiển thị hạng cũ/mới/rewards; Continue và Share đúng callback; Share chỉ hiện khi có `onShare`; semantics; Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) mở dialog, Share rồi Continue gọi caller seam qua showcase thật; không dùng simulator.
- [x] **Golden test**: bronze→silver và gold→diamond có rewards trên baseline/dark/vi/RTL/textScale/reducedMotion (`rank_promotion_dialog_golden_test.dart`). Golden đã bắt overflow badge ở textScale 2.0, sửa bằng `FittedBox`.
- [x] **Interruption test**: Unmount giữa entrance dispose controller hào quang, không ném lỗi hay gọi callback. Chưa kiểm chứng pause/resume thật.
- [x] **Network conditioning test**: N/A — widget thuần presentation.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-147.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming entrance + hào quang.
- [x] **IAP & Ad mediation test**: N/A — Share là callback caller sở hữu.

## Hiệu năng & Animation
- [x] Hào quang dùng `SunburstGodRays` hiện có, `RepaintBoundary` cô lập; Reduced Motion dừng vòng quay.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
