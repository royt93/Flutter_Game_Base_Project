---
id: ENH-127
title: "Jank/frame-rate và memory profiling trên S24U: một lệnh chạy tay, kết quả vào docs/qa"
type: enhancement
layer: example/integration_test + docs/qa
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- Có 18 integration test dạng `*_perf_test.dart` và `d4_perf_memory_test.dart` trong `example/integration_test/`, `profile_driver.dart` chỉ gọi `integrationDriver()`. `tool/performance_budget_policy.json` hiện CHỈ có 3 chỉ số (`object_pool_allocation_reduction_percent`, `object_pool_pooled_elapsed_us`, `example_app_boot_wall_ms` trên thiết bị thật). Chưa có chỉ số jank hay bộ nhớ trong chính sách.
- Đã kiểm: các `*_perf_test` đo bằng `SchedulerBinding.instance.addTimingsCallback` thu `FrameTiming` (ví dụ `profile_stats_card_perf_test.dart` dòng 16-50, `framePolicy = fullyLive`), không dùng `traceAction`. Chưa đọc kỹ ngưỡng nào họ khẳng định (bước 1).
- Owner chọn: jank + memory chạy TAY trên S24U (SM_S928B, chọn theo model, không simulator), ghi `docs/qa`; không đưa vào CI. Lý do: emulator dùng GPU giả lập (swiftshader) nên số jank/memory không đáng tin.

## Phạm vi

Một lệnh (script ngắn trong `tool/` hoặc lệnh ghi trong `docs/qa`) chạy bộ perf trên S24U, thu: tỉ lệ frame trễ (build/raster, p90/p99), thời gian khởi động, bộ nhớ (RSS hoặc `dumpsys meminfo`) trước/sau một ván Match-3 và sau điều hướng lặp 11 màn Home; kết quả ghi vào `docs/qa/device_matrix.md`. Nếu thêm chỉ số vào `performance_budget_policy.json` thì cần baseline thật và owner đồng ý ngưỡng.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc 3 test perf tiêu biểu và `d4_perf_memory_test.dart`; ghi cách chúng đo và mức tin cậy vào "Kết quả thực hiện".
- [ ] 2. Chọn kịch bản đo (Match-3 một ván, điều hướng Home 11 màn × 3 vòng, cuộn Widget Showcase) và chỉ số; ghi ngưỡng đề xuất dựa trên số đo ĐẦU TIÊN (chưa có baseline, không đặt ngưỡng đoán).
- [ ] 3. Tận dụng cách `addTimingsCallback` + `FrameTiming` đã có trong các `*_perf_test` (tính p90/p99 của `buildDuration` và `rasterDuration`); `IntegrationTestWidgetsFlutterBinding.watchPerformance`/`traceAction` có trong `integration_test` nhưng KHÔNG cần thiết nếu cách hiện có đủ; thêm bước đo bộ nhớ qua `adb shell dumpsys meminfo <package>` trước/sau.
- [ ] 4. Chạy trên S24U (chọn theo model; kiểm app foreground trước vì máy dùng chung) 3 lần; ghi trung vị và độ lệch; KHÔNG chạy trên emulator để lấy số.
- [ ] 5. Ghi kết quả vào `docs/qa/device_matrix.md` (kèm thời điểm, máy, bản app, lệnh). Nếu muốn đưa vào chính sách ngân sách: thêm chỉ số với `requiredSource: realDevice` và `maxAgeMs`, owner chốt ngưỡng.
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate (nếu sửa `performance_budget_policy.json` thì `dart run tool/performance_budget_check.dart check`). Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Một lệnh chạy được toàn bộ phép đo trên S24U.
- [ ] Kết quả có trung vị của 3 lần chạy và được ghi vào `docs/qa`.
- [ ] Không dùng số đo từ emulator làm bằng chứng.
- [ ] Mọi ngưỡng mới dựa trên số đo thật, có owner đồng ý.

## Lệnh kiểm chứng nhanh

- `cd example && flutter test integration_test/<file>_perf_test.dart -d <S24U> --dart-define=E2E_TEST=true`
- `dart run tool/performance_budget_check.dart check`
