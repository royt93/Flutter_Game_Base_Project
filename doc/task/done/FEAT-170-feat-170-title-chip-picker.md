---
id: FEAT-170
title: TitleChipPicker — Bộ chọn danh hiệu dạng chip với trạng thái khoá và đang dùng
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Người chơi có thể đạt nhiều danh hiệu (ví dụ "Explorer", "Streak Master") và cần chọn một danh hiệu hiển thị cạnh tên. Chưa có UI chọn danh hiệu; không nên tái dùng `SegmentedTabBar` vì số lượng lớn, độ dài chữ khác nhau và có trạng thái khoá.

## Đề xuất phạm vi
Widget `TitleChipPicker` hiển thị:
- Danh sách `TitleOption(id, label, locked, unlockHint?)`, id duy nhất, xếp bằng `Wrap` tự xuống dòng.
- Chip đang dùng (`selectedId`) nhấn mạnh; chip khoá có biểu tượng khoá và mờ.
- Tuỳ chọn "Không dùng danh hiệu" (`noneLabel`) đặt `selectedId == null`.
- `onSelect(id)` cho chip đã mở; `onLockedTap(id)` cho chip khoá (caller hiện `unlockHint`), không tự đổi lựa chọn.
- Nhãn dài hiển thị tối đa 2 dòng rồi cắt; không tràn ngang ở 320dp + textScale 2.0.
- Presentation-only: caller sở hữu danh sách, trạng thái mở khoá và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho id/label rỗng, ID trùng, selectedId không tồn tại hoặc đang khoá, `noneLabel` rỗng.
- [x] **Widget test**: 9 test: chưa chọn/đang chọn/khoá/danh sách rỗng, chọn unlocked và no-title, locked callback riêng, locked không handler bất hoạt, target >=48dp, semantics có tên/equipped/locked hint/tap action, nhãn rất dài cắt tối đa 2 dòng, 320dp + textScale 2.0 + RTL thật, reduced motion và unmount.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-19: chọn `Streak Master`; chạm `Legendary Champion` chỉ gọi locked seam, selectedId giữ nguyên; không dùng simulator. Foreground là Home launcher. Log `/tmp/feat170_smoke.log`.
- [x] **Golden test**: 28 ảnh (none/selected/locked/long × 7 biến thể), viewport 390×844. Baseline từ workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `title_chip_picker_*`, lockfile giữ nguyên. Font test dạng khối.
- [x] **Interruption test**: đổi lựa chọn và unmount không để ticker mồ côi.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: picker không tạo ticker/controller; reduced motion/unmount có test host.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 100 titles/180 lựa chọn: 438 frame; totalSpan p50/p95/p99 = 7,493/22,129/27,680ms; max(build,raster) = 5,693/14,929/21,303ms; 13 frame vượt 16,667ms (2,97%). Đây là quan sát benchmark trên cấu hình 100 chip nhiều dòng, không chứng minh compositor/missed-vsync hay 60 FPS bền vững. Log `/tmp/feat170_profile.log`.
- [x] **IAP & Ad mediation test**: N/A — nguồn unlock do caller quản lý.

## Hiệu năng & Animation
- [x] `Wrap` tự xuống dòng, label tối đa 2 dòng, 48dp targets. Tái dùng `PressableScale`; reduced motion tắt press bounce theo widget nền tảng. Không thêm animation controller.

## Chạy lại
```bash
flutter test test/widget/common/title_chip_picker_test.dart test/widget/goldens/title_chip_picker_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-170
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-170
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/title_chip_picker_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
