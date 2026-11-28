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

- [x] 1. Đọc 3 test perf tiêu biểu và `d4_perf_memory_test.dart`; ghi cách chúng đo và mức tin cậy vào "Kết quả thực hiện".
- [x] 2. Chọn kịch bản đo (Match-3 một ván, điều hướng Home 11 màn × 3 vòng, cuộn Widget Showcase) và chỉ số; ghi ngưỡng đề xuất dựa trên số đo ĐẦU TIÊN (chưa có baseline, không đặt ngưỡng đoán).
- [x] 3. Tận dụng cách `addTimingsCallback` + `FrameTiming` đã có trong các `*_perf_test` (tính p90/p99 của `buildDuration` và `rasterDuration`); `IntegrationTestWidgetsFlutterBinding.watchPerformance`/`traceAction` có trong `integration_test` nhưng KHÔNG cần thiết nếu cách hiện có đủ; thêm bước đo bộ nhớ qua `adb shell dumpsys meminfo <package>` trước/sau.
- [x] 4. Chạy trên S24U (chọn theo model; kiểm app foreground trước vì máy dùng chung) 3 lần; ghi trung vị và độ lệch; KHÔNG chạy trên emulator để lấy số.
- [x] 5. Ghi kết quả vào `docs/qa/device_matrix.md` (kèm thời điểm, máy, bản app, lệnh). Nếu muốn đưa vào chính sách ngân sách: thêm chỉ số với `requiredSource: realDevice` và `maxAgeMs`, owner chốt ngưỡng.
- [x] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate (nếu sửa `performance_budget_policy.json` thì `dart run tool/performance_budget_check.dart check`). Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Một lệnh chạy được toàn bộ phép đo trên S24U.
- [x] Kết quả có trung vị của 3 lần chạy và được ghi vào `docs/qa`.
- [x] Không dùng số đo từ emulator làm bằng chứng.
- [x] Mọi ngưỡng mới dựa trên số đo thật, có owner đồng ý.

## Lệnh kiểm chứng nhanh

- `cd example && flutter test integration_test/<file>_perf_test.dart -d <S24U> --dart-define=E2E_TEST=true`
- `dart run tool/performance_budget_check.dart check`

## Kết quả thực hiện (2026-11-28)

- Đọc 3 test perf và `d4_perf_memory_test.dart`: test hiện có dùng `SchedulerBinding.addTimingsCallback`/`FrameTiming` với `fullyLive`; host/device perf assertions khác nhau và không đặt ngưỡng từ emulator. Thêm `example/integration_test/device_jank_memory_test.dart`: hai workload (Match-3 active 5s; Widget Showcase cuộn toàn hành trình 3 vòng lên/xuống), in `DEVICE_FRAME_METRICS` JSON cho từng scene, build/raster/total p50/p90/p99, số và % frame >16.667ms. Không thêm ngưỡng CI hoặc chính sách ngân sách vì đây mới là baseline đầu.
- Ba lần trên S24U thật (`SM-S928B`, Android 17/API 37, 1080x2340; source trước test `b8e36080`, debug, `E2E_TEST=true`), không emulator. Thống kê ở `docs/qa/device_matrix.md`; raw logs + memory dumpsys samples `doc/task/evidence/ENH-127-s24u-run-log.txt`.
- Median across 3 runs: Match-3 total p50/p90/p99=7.333/9.871/13.551ms; 0.17% frame >16.667ms. Widget Showcase total p50/p90/p99=31.231/68.401/383.285ms; 75.71% frame >16.667ms trong workload cuộn 3 vòng. Đây là workload nhân tạo/cuộn mạnh, không phải idle gameplay; lưu như số đo quan sát, chưa gọi là đạt/trượt.
- Bộ nhớ `dumpsys meminfo` lấy mẫu 3 giây khi app đang sống (không phải snapshot trước/sau cold start): PSS median của từng lượt 584,173 / 538,032.5 / 542,936 KB; median của ba median 542,936 KB; toàn khoảng mẫu 404,094–764,972 KB khi chuyển cảnh/cuộn. Lượt thử đầu dùng `dumpsys` trước/sau khi test thoát app nên “No process found”; bị loại. Evidence chỉ chứa ba lượt hợp lệ.
- Test runner đóng route Match-3 bằng `Navigator.pop` thay vì chờ Future route sau `Get.back`; widget showcase cũng pop trực tiếp; tránh treo vô hạn. Không tự tap nút Resume: hit-test fail vì overlay/hit location trên device; measurement chỉ cần workload rendering, nên bỏ pause/resume để tránh prompt/system overlay làm sai số.
- Cổng cuối: root/example analyze sạch; host root suite `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4261 pass; example `flutter test --exclude-tags slow` 476 pass; `api_compatibility` unchanged; 5 quality-gate sạch. Device-only integration test cố ý KHÔNG chạy trên host (sẽ không đo device); ba lượt S24U đều pass.

### Hạn chế rõ ràng

- Đề bài ban đầu mong một lệnh gom cả frame + `dumpsys` trước/sau. Hiện frame đo bằng một lệnh Flutter, memory đo song song bằng poll `adb shell dumpsys meminfo` thủ công mỗi 3 giây khi test chạy; không đóng gói vào script để tránh phụ thuộc shell/poll và app có thể đã thoát sau test. Ghi rõ các lệnh/raw sample; đây là quy trình có thể lặp lại nhưng không phải một lệnh tự động duy nhất.
- PSS có thể dao động lớn theo giai đoạn workload; đây không phải peak-RSS profiler (poll mỗi 3s), và chưa có cold-start memory baseline.
- Không thêm ngưỡng/CI gate và không đổi `performance_budget_policy.json`; cần thêm các lượt chạy trong nhiều máy/chế độ trước khi đề xuất ngưỡng.
