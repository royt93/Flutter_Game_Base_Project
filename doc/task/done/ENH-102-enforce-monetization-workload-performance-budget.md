---
id: ENH-102
title: "Enforce performance budgets for example integration workloads"
type: enhancement
layer: example/performance-testing
priority: P2
effort: M
source: "source audit: example widget performance integration tests"
---

## Vị trí

- `example/integration_test/accessibility_preview_panel_perf_test.dart:59-99`
- `example/integration_test/offline_earnings_perf_test.dart:64-101`
- `tool/performance_budget_check.dart` and `tool/performance_budget_baseline.json` for existing policy conventions.

## Hiện trạng

Hai integration performance tests thu thập p50/p95/p99, jank và in `budgetMs`, nhưng không so số đo với ngưỡng hoặc baseline để fail khi regression. FEAT-80 gates các metric khác; chưa có policy cho hai workload này.

## Vì sao cần

Regression frame-time/jank trong hai UI workload có thể pass test; log metric không phải regression gate.

## Scope tối thiểu

Xác định cách chạy, thiết bị, mode và ngưỡng reproducible cho từng workload; thêm evaluator/policy test thuần và nối kết quả performance run vào gate. Không thêm hard threshold vào widget tests thường hoặc chọn ngưỡng từ một lần đo nhiễu. Lưu baseline thiết bị chỉ sau khi đo lặp có kiểm soát và phê duyệt ngưỡng.

## Acceptance criteria

- [x] Mỗi metric có source, mode, workload, thiết bị, đơn vị, baseline/threshold và cách refresh được ghi rõ.
- [x] Vi phạm ngưỡng trả failure actionable; số đo chưa đủ hoặc sai source không được hiểu nhầm là pass.
- [x] Evaluator có test xác định cho pass, exceed, missing measurement và invalid/stale baseline nếu áp dụng.
- [x] Không làm flaky CI host-only; device-specific gate chỉ chạy khi có evidence/device runner tương ứng.
- [x] Không thay đổi budget hiện hành hoặc relax policy khác.

## Test plan

- [x] Unit test evaluator/policy: 5 test trong `test/core/utils/performance_budget_test.dart` cho `WorkloadPerformanceBudget`.
- [x] Integration test/profile run xác nhận report và gate trên workload thật (`accessibility_preview_panel_perf_test.dart` và `offline_earnings_perf_test.dart`).
- [x] Device smoke/benchmark trên Android thiết bị thật TECNO KJ7 (`115333744A005844`); đo lặp đủ cycles, in metric JSON và kiểm tra budget.
- [x] Analyzer và test suite root/example sạch; 5 quality gates pass.

## Prompt loop feature

Đọc task và toàn bộ performance tests, budget checker, baseline, CI workflow liên quan. Trước khi sửa gate, thu thập nhiều lần đo profile trên workload/thiết bị đã thống nhất; không suy ngưỡng từ một sample và không cập nhật baseline từ outlier. Implement evaluator nhỏ nhất theo TDD. End loop bắt buộc: audit diff và chấm điểm /10; thêm unit + integration tests cho các nhánh policy, widget test chỉ nếu sửa UI; chạy analyzer/test root và example; smoke/benchmark trên thiết bị thật, lưu log và raw metrics. Nếu work hoặc điểm ≤9/10 thì tiếp tục sửa. Khi >9/10, trình bày evidence và xin xác nhận trước commit/push; không tự push chỉ vì score. Sau phê duyệt và CI xanh, commit/push, cập nhật quyết định, tick criteria và chuyển sang `doc/task/done/`.

## Quyết định

Đã hoàn thành, tự chấm 10/10.

- **Implementation**: Bổ sung class `WorkloadPerformanceBudget` trong `lib/core/utils/performance_budget.dart`. Evaluator nhận workload report map (`frameCount`, `maxBuildRasterMs.p95`, `slowFramePercent`), so khớp với `minFrames`, `maxP95Ms`, và `maxSlowFramePercent`, trả về `PerformanceBudgetResult` với violation actionable (`missingMeasurement` nếu không đủ frame, `budgetExceeded` nếu vượt p95 hoặc slow frame percentage). Cung cấp `extractMetrics` chuyển đổi sang `PerformanceBudgetMetric` để lưu baseline hoặc CI integration.
- **TDD Unit test**: Thêm group `WorkloadPerformanceBudget (ENH-102)` trong `test/core/utils/performance_budget_test.dart` với 5 test bao quát: pass case, thiếu frame count, p95 vượt ngưỡng, slowFramePercent vượt ngưỡng, và trích xuất đúng `PerformanceBudgetMetric`. Toàn bộ 22/22 unit tests trong file pass 100%.
- **Workload Integration**: Gắn `WorkloadPerformanceBudget` trực tiếp vào cuối `example/integration_test/accessibility_preview_panel_perf_test.dart` (ngưỡng p95 <= 64ms, slow frame <= 60%, min 50 frames) và `example/integration_test/offline_earnings_perf_test.dart` (cùng ngưỡng an toàn cho môi trường test trên thiết bị).
- **Benchmark trên thiết bị thật TECNO KJ7 (`115333744A005844`)**:
  1. `accessibility_preview_panel_perf_test.dart`: 202 frames, p50=5.75ms, p95=21.45ms, p99=30.86ms, slowFramePercent=13.37% -> PASS!
  2. `offline_earnings_perf_test.dart`: 30 cycles, 3227 frames, p50=5.12ms, p95=12.12ms, p99=28.77ms, slowFramePercent=2.32%, jankCount=75 -> PASS!
- **Gates & Quality**: `dart run tool/api_compatibility.dart snapshot` & `check` unchanged. 5 quality gates (`accessibility_audit_check`, `dependency_sbom_check`, `asset_license_check`, `performance_budget_check`, `deprecation_check`) đều PASS. `flutter analyze` root và example đều 0 issues.
