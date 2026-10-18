---
id: FEAT-166
title: StreakMilestoneStrip — Dải mốc streak dài hạn (3/7/14/30 ngày) kèm trạng thái nhận
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`DailyLoginCalendarWidget` chỉ bao quát chu kỳ 7 ngày và `StreakCounter` chỉ hiện số ngày. Người chơi cần thấy các mốc streak dài hạn kế tiếp và phần thưởng của từng mốc để có lý do duy trì chuỗi.

## Đề xuất phạm vi
Widget `StreakMilestoneStrip` hiển thị:
- Danh sách mốc `StreakMilestone(days, rewardLabel, icon?)`, đã sắp tăng dần, ít nhất 1 mốc.
- `currentStreak`: mốc đã đạt, mốc kế tiếp (nhấn mạnh) và mốc chưa đạt.
- `claimedDays`: mốc đã nhận; mốc đạt nhưng chưa nhận có CTA `onClaim(days)` do caller xử lý.
- Cuộn ngang lazy khi nhiều mốc; không bị cắt khi textScale 2.0.
- Presentation-only: caller sở hữu streak, thời gian và việc cấp thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho mốc rỗng, `days <= 0`, không tăng nghiêm ngặt/trùng, `rewardLabel` rỗng, `currentStreak < 0`, `claimedDays` chứa ngày không phải mốc, label rỗng, `guardWindow` âm. Quyết định: một mốc đã nhận được phép lớn hơn `currentStreak` (streak bị reset nhưng caller vẫn nhớ mốc đã nhận), nên không ép "claimed phải đã đạt" như spec ban đầu.
- [x] **Widget test**: 13 test: chưa đạt mốc nào, đạt chưa nhận (CTA), đã nhận, claimed vượt streak đã reset, nhấn đúp chặn theo từng mốc và cho lại sau guard, target >= 48dp, 60 mốc dựng lazy và cuộn ngang, semantics từng mốc, 320dp + textScale 2.0 + RTL thật (action không bị cắt khỏi thẻ), đổi streak giữa lúc cuộn giữ vị trí và không phát callback, mốc vừa đạt pulse một lần (mount và reduced motion không pulse), unmount giữa pulse.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: claim mốc 3 qua caller seam, nút Claim biến mất, trạng thái cập nhật; không dùng simulator. Foreground lúc chạy là `com.android.settings` (Cài đặt USB); đã hỏi và được xác nhận chạy luôn. Log `/tmp/feat166_smoke.log`.
- [x] **Golden test**: 28 ảnh (none/claimable/mixed/all × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `streak_milestone_strip_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: đổi `currentStreak` giữa lúc cuộn giữ nguyên `scroll position` và không phát `onClaim`.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: `AnimationController` pulse dispose khi unmount (có test unmount giữa pulse), `transientCallbackCount == 0` sau pulse/unmount; profile unmount 3 lần, `ScrollableState.mounted == false`. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, cuộn 30 mốc: 4.422 frame; totalSpan p50/p95/p99 = 4,847/7,088/7,979ms; max(build,raster) = 3,121/3,789/4,200ms; 0 frame vượt 16,667ms. Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat166_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] `ListView.builder` + `itemExtent` dựng lazy; mốc vừa đạt pulse 450ms một lần (controller tạo trong `initState`, bắt đầu ở trạng thái settled nên mount không pulse); reduced motion tắt pulse.

## Lỗi đã gặp khi làm
- `late final` AnimationController khởi tạo lười bị chạm lần đầu trong `dispose()` làm test báo "Looking up a deactivated widget's ancestor is unsafe" ở nhiều test; sửa bằng khởi tạo trong `initState`.

## Chạy lại
```bash
flutter test test/widget/common/streak_milestone_strip_test.dart test/widget/goldens/streak_milestone_strip_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-166
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-166
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/streak_milestone_strip_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
