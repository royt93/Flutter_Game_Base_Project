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
- [x] **Unit test**: runtime `ArgumentError` cho `rewardLabel`/`remainingText`/`readyLabel`/`semanticLabel` rỗng, `progress` âm, > 1, NaN, vô hạn; biên 0 và 1 hợp lệ.
- [x] **Widget test**: 11 test: đang tiến hành (có thanh), không progress (ẩn thanh), sẵn sàng (đổi sang `readyLabel`, ẩn thanh, hiện dot), tap + target >= 48dp, semantics nêu thưởng và còn thiếu/sẵn sàng và có tap action, text dài `maxLines == 1` + ellipsis, 320dp + textScale 2.0 + text dài + RTL thật, đổi trạng thái liên tục rồi unmount, reduced motion vẫn đổi nhãn không chạy ticker, pulse chạy khi cho phép animation.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: +1 win hai lần chip chuyển sang Claim, tap mở overlay caller rồi đóng; không dùng simulator. Foreground lúc chạy là Home launcher (không có app khác). Log `/tmp/feat167_smoke.log`.
- [x] **Golden test**: 28 ảnh (progress/noprogress/ready/long × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `next_reward_teaser_chip_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: đổi qua lại in-progress/ready 20 lần kèm đổi progress rồi unmount, `transientCallbackCount == 0`.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: `transientCallbackCount == 0` sau unmount và khi reduced motion; profile unmount 3 lần không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 540 lần đổi trạng thái: 1.189 frame; totalSpan p50/p95/p99 = 5,037/7,001/8,932ms; max(build,raster) = 2,765/3,495/4,275ms; 2 frame vượt 16,667ms (0,168%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat167_profile.log`.
- [x] **IAP & Ad mediation test**: N/A — widget không biết nguồn thưởng/quảng cáo.

## Hiệu năng & Animation
- [x] Trạng thái sẵn sàng tái dùng `BadgeDot(pulse: true)` (tự tắt khi reduced motion); thanh tiến độ `TweenAnimationBuilder` 300ms, `Duration.zero` khi reduced motion. Không tạo controller riêng.

## Chạy lại
```bash
flutter test test/widget/common/next_reward_teaser_chip_test.dart test/widget/goldens/next_reward_teaser_chip_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-167
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-167
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/next_reward_teaser_chip_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
