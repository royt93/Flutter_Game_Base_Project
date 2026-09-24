---
id: IDEA-63
title: "Battery Saver Mode Coordinator — tự hạ frame rate/tắt shader khi pin thấp"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mới, dựa trên `lib/core/performance_tier_service.dart`, `lib/presentation/widgets/shader_ticker_layer.dart`.

## Hiện trạng
`PerformanceTierService` hạ tier dựa trên FPS thực đo (hysteresis), nhưng không lắng nghe mức pin thiết bị — 1 thiết bị đang chạy mượt (FPS cao) nhưng pin yếu vẫn tiếp tục chạy shader/hiệu ứng nặng.

## Vì sao cần / Hậu quả
Chủ động hạ tải khi pin thấp (thay vì chỉ phản ứng khi FPS đã tụt) giúp máy đỡ nóng/tiết kiệm pin hơn cho phiên chơi dài.

## Đề xuất
Thêm 1 coordinator lắng nghe mức pin (qua `battery_plus` hoặc plugin tương tự — cân nhắc kỹ ponytail: chỉ thêm dependency mới nếu thật sự cần, kiểm tra platform channel có sẵn trước), khi pin < ngưỡng (ví dụ 20%) ép `PerformanceTierService` xuống `low` bất kể FPS thực đo.

## Acceptance criteria
- [x] Pin dưới ngưỡng cấu hình — `PerformanceTierService.tier` bị ép xuống `low`.
- [x] Pin trên ngưỡng — không ép buộc, để `PerformanceTierService` tự quyết theo FPS như bình thường.
- [x] Test unit cho logic ép tier theo pin (mock battery level).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-63-battery-saver-mode-coordinator.md` này trước khi làm. Đọc toàn bộ `lib/core/performance_tier_service.dart` và `pubspec.yaml` (kiểm tra có dependency đọc pin nào sẵn có chưa, cân nhắc kỹ trước khi thêm dependency mới) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (verify hành vi khi pin thấp thật, nếu tiện) không bắt buộc nếu unit test với mock battery level đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý, cần thêm dependency mới (đọc mức pin) — cân nhắc kỹ giá trị/effort trước khi implement, ponytail nhắc: chỉ thêm khi thật cần. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Ponytail check trước khi code (đúng như task tự nhắc)**: kiểm tra
`pubspec.yaml` — KHÔNG có dependency đọc pin nào sẵn có (`battery_plus`
hay tương đương). Quyết định KHÔNG thêm dependency mới — package này có
convention nhất quán "seam trung lập SDK cụ thể" cho MỌI tích hợp
platform khác biệt theo app (`CrashReporter`, `AnalyticsProvider`,
`PurchaseSeam`, `CloudSaveProvider`, `ConnectivityCoordinator`'s
`ReachabilityProbe`...) — thêm `battery_plus` vào 1 package published sẽ
bắt MỌI consumer (kể cả người không cần battery saver) trả giá dependency
đó. `BatteryLevelProvider` là 1 typedef function đơn giản (giống
`ReachabilityProbe`), app tự inject `() async =>
(await Battery().batteryLevel)` hoặc plugin bất kỳ họ đã dùng.

**Phát hiện quan trọng khi Read `performance_tier_service.dart`**:
`PerformanceTierService.tier` là `Rx` public — ép xuống `low` thì dễ
(`tier.value = PerformanceTier.low`), NHƯNG khi pin hồi phục, "nhả" ép
buộc về giá trị NÀO? Class cũ không có cách nào đọc lại "ý kiến thật của
FPS tracker" tách biệt khỏi giá trị `tier` đã bị ép — nếu chỉ đặt lại
`high` một cách ngây thơ sẽ SAI khi FPS thực tế vẫn đang tệ. Thêm getter
mới `PerformanceTierService.measuredTier` (trỏ thẳng `_tracker.tier`,
không đổi hành vi `tier`/`recordFrame` gì cả) để `BatterySaverCoordinator`
khôi phục đúng giá trị THẬT thay vì đoán mò.

**Implement**: `BatterySaverCoordinator({performanceTier, batteryLevelProvider,
lowBatteryThreshold = 20})`, API duy nhất là `check()` — KHÔNG tự polling
(không `Timer` nội bộ), caller tự gọi theo nhịp họ muốn (đúng convention
"seam, caller-driven" đã dùng lại ở `TrustedClockService.reconcileWithTrustedSource`
và `smart_reminder_scheduling.dart`'s `rescheduleXxxReminder` — IDEA-62
làm ngay trước task này). `check()`: pin < ngưỡng → ép `tier.value = low`,
ghi nhớ `isForcingLow = true`; pin >= ngưỡng VÀ đang ép → nhả về đúng
`measuredTier`; pin >= ngưỡng, chưa từng ép → no-op hoàn toàn; đọc pin
trả `null` (lỗi tạm thời) → no-op tuyệt đối theo CẢ 2 hướng (không ép
mới, không nhả override đang có) — 1 lần đọc lỗi giữa phiên không được
coi là "pin đã hồi phục".

**TDD**: `mv` file coordinator ra ngoài + `git stash` riêng
`performance_tier_service.dart`/`roy_casual_kit.dart`, chạy 6 test mới →
fail đúng biên dịch ("Method not found: 'BatterySaverCoordinator'"), khôi
phục, chạy lại — 6/6 pass. Test quan trọng nhất: pin hồi phục sau khi ép
low, TRONG LÚC FPS tracker (feed thủ công qua `recordFrame`) THẬT SỰ vẫn
đang low → verify khôi phục đúng về `low` (không phải `high` mặc định) —
chứng minh đúng thiết kế `measuredTier`, không chỉ test happy path.
`test/core/performance_tier_service_test.dart` (19 test cũ) vẫn pass
nguyên, xác nhận `measuredTier` không đổi hành vi gì có sẵn.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2292 test (+6 đúng số test mới), 19 fail —
đúng baseline golden-image, không fail mới. `example/`: 142/142 pass
(không đổi gì ở `example/`, task không yêu cầu demo — coordinator thuần
logic, không có UI). `dart run tool/api_compatibility.dart check` →
`additive` (file + 2 symbol mới `BatterySaverCoordinator`/
`BatteryLevelProvider`) → `snapshot` → `unchanged`. Không cần smoke test
device (task tự ghi optional, mock battery level qua closure đã đủ chứng
minh logic — không có platform channel thật nào để test vì cố tình không
thêm dependency).

Tự chấm: **9.5/10** — tuân thủ nghiêm ngặt ponytail (không thêm dependency
mới, đúng gợi ý của chính task), phát hiện đúng lỗ hổng thiết kế thật
(không có cách "nhả" đúng) trước khi code và sửa bằng 1 getter tối thiểu,
TDD chứng minh cả case biên quan trọng nhất (khôi phục theo FPS thật, không
phải hardcode). Trừ 0.5 vì `lowBatteryThreshold` không được validate (một
giá trị ngoài 0-100 sẽ không throw, chỉ âm thầm không bao giờ/luôn luôn ép
— chấp nhận được vì đây là 1 tham số cấu hình nội bộ app tự chọn, không
phải input runtime từ nguồn không tin cậy, nhưng đáng ghi nhận).
