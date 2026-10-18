---
id: FEAT-167
title: NextRewardTeaserChip — Chip gợi ý phần thưởng kế tiếp kèm tiến độ còn thiếu
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
Người chơi cần một lời nhắc ngắn kiểu "còn 2 trận nữa mở rương" ở màn hình chính hoặc kết thúc màn, mà không phải mở `StarChestProgressHud`, `RewardTrackRoad` hay `BattlePassRoad`. Chip gọn này gợi ý mục tiêu gần nhất và dẫn tới màn đầy đủ của caller.

## Đề xuất phạm vi
Widget `NextRewardTeaserChip` hiển thị:
- Icon/`rewardLabel` của phần thưởng kế tiếp và `remainingText` do caller định dạng (vd `2 wins to go`).
- Tiến độ nhỏ `progress` (0..1) tuỳ chọn.
- Trạng thái sẵn sàng (`ready: true`): đổi sang `readyLabel` (vd `Claim`) và nhấn mạnh.
- `onTap()` mở màn tiến độ hoặc nhận thưởng do caller sở hữu.
- Presentation-only; không tính tiến độ, không biết nguồn thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `rewardLabel`/`remainingText`/`readyLabel` không rỗng, `progress` trong 0..1 và hữu hạn; `ArgumentError` runtime.
- [ ] **Widget test**: đang tiến hành, sẵn sàng, không có progress, tap, semantics nêu thưởng và còn thiếu, text dài ellipsis một dòng, 320dp + textScale 2.0 gutter 16dp, RTL thật, target >= 48dp.
- [ ] **Integration test (Device)**: tap chip mở overlay tiến độ qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground trước khi chạy.
- [ ] **Golden test**: `runGoldenMatrix` tiến hành/sẵn sàng/text dài × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1.
- [ ] **Interruption test**: đổi giữa tiến hành và sẵn sàng liên tục không để lại animation mồ côi.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: không còn ticker sau unmount/reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi đổi trạng thái liên tục (profile thiết bị thật), ghi rõ giới hạn engine timing.
- [ ] **IAP & Ad mediation test**: N/A — không biết nguồn thưởng/quảng cáo.

## Hiệu năng & Animation
- [ ] Trạng thái sẵn sàng có nhịp nhẹ tái dùng `BadgeDot`/`PressableScale`; `reducedMotion` tắt nhịp, vẫn đổi nhãn đúng.
