---
id: FEAT-159
title: CharacterCollectionGrid — Bộ sưu tập nhân vật owned/locked với rarity và filter
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Progression, Crafting & Collection Meta UI (Wave 14)
---

## Vì sao cần
Game có nhiều nhân vật cần một màn collection giúp người chơi xem nhân vật sở hữu/chưa mở, rarity và chọn nhân vật hiện hành. Grid cần hoạt động với catalog dài mà không tự quản lý entitlement hay equip state.

## Đề xuất phạm vi
Widget `CharacterCollectionGrid` hiển thị:
- Danh sách `CharacterCollectionItem` caller cung cấp: id, tên, rarity, asset/icon, owned/selected state.
- Filter All/Owned/Locked và highlight selection hiện tại.
- Tap nhân vật gọi `onCharacterTap(characterId)`; action chọn gọi `onSelect(characterId)` nếu caller cho phép.
- Lazy 3-column grid; names dài dùng ellipsis, semantics nêu rarity và locked/owned.
- Presentation-only: caller xác thực unlock/equip và cung cấp catalog/asset.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate IDs duy nhất, tên không rỗng, trạng thái selection nhất quán (`character_collection_grid_test.dart`).
- [x] **Widget test**: Filter, rarity/owned/locked badges, current selection, tap/select callbacks, empty state, semantics và textScale 2.0 (`character_collection_grid_test.dart`). Widget không có animation/ticker nội bộ; Reduced Motion được phủ trong Golden Matrix.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) filter/select nhân vật qua caller seam; pass, không dùng simulator.
- [x] **Golden test**: 14 PNG baseline comparisons cho owned/locked/selected và empty trên light/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844. Android tap-target và labeled-target guidelines bật; test riêng xác nhận vùng 48dp nhận tap sát mép và viewport 320dp/textScale 2.0 không overflow.
- [x] **Interruption test**: Test catalog 60 nhân vật xác nhận lazy rendering, đổi filter khi đang scroll, unmount/remount không throw và selection caller-owned được khôi phục.
- [x] **Network conditioning test**: N/A — catalog/unlock sync thuộc caller.
- [x] **Memory leak & profiling test**: Pixel 7 Pro debug (`character_collection_perf_test.dart`, 2026-10-18): 60 nhân vật, 5 chu kỳ mount/scroll/unmount, 5 `ScrollPosition` đã dispose (kiểm tra trực tiếp `ChangeNotifier.debugAssertNotDisposed`), MemoryWatchdog có 0 orphan mới. RSS sau mỗi unmount: 483.504.128 / 496.951.296 / 467.034.112 / 480.784.384 / 479.129.600 byte. Watchdog handle do test đăng ký và release sau khi xác nhận disposal; không tự quét allocation của widget, không chứng minh toàn bộ heap không leak.
- [x] **Frame rate / Jank test**: Pixel 7 Pro profile qua `flutter drive --profile` (`character_collection_perf_test.dart`, 2026-10-18): 3.547 frames, totalSpan p50/p95/p99 = 6.023/10.470/13.729ms, max(build,raster) p50/p95/p99 = 4.364/5.393/6.548ms, slow-frame 0,0846%, jank 3 với ngưỡng max(build,raster) > 16.667ms. Mẫu là scroll 60 nhân vật 32 giây sau warm-up. Đây là engine FrameTiming, không phải số missed-vsync từ compositor.
- [x] **IAP & Ad mediation test**: N/A — unlock/purchase logic ở caller.

## Hiệu năng & Animation
- [x] `GridView.builder` lazy rendering; avatar widget chỉ được gắn vào cell đang build.
- [x] Sustained benchmark đã đo cửa sổ 32 giây trên Pixel 7 Pro: 3/3.547 frames vượt budget 60Hz, p99 engine frame latency 13.729ms. Không đạt tiêu chí zero-jank tuyệt đối; chưa đo thiết bị yếu, portrait thật hoặc thermal soak nhiều phút, không cam kết 60 FPS cho các trường hợp đó.

## Chạy lại
```bash
flutter test test/widget/common/character_collection_grid_test.dart test/widget/goldens/character_collection_grid_golden_test.dart
cd example
flutter test integration_test/character_collection_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/character_collection_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
MemoryWatchdog chỉ hoạt động ở debug. Profile kiểm tra unmount và lấy FrameTiming/RSS, không dùng kết quả orphan profile để kết luận leak. Catalog thử nghiệm dùng icon mặc định, không tải portrait/network hoặc can thiệp save thật.
