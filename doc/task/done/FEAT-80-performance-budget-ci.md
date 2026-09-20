---
id: FEAT-80
title: "Performance Budget CI"
type: feature
layer: tooling/performance
priority: P1
effort: M
depends_on: [FEAT-39, FEAT-47, FEAT-48]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Đặt budget frame time, shader compile, asset load, memory và test regression trong CI.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Benchmark device/emulator policy rõ; kết quả reproducible và có baseline.
- [x] Vi phạm budget fail đúng stage, report actionable.
- [x] Smoke device thật xác nhận metric không chỉ pass trên host.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/utils/performance_budget.dart` — framework thuần Dart, không
phụ thuộc Flutter, không tự đo gì cả: chỉ nhận `PerformanceBudgetMetric`
(đã đo sẵn từ nơi khác) + `BudgetPolicy` rồi `checkPerformanceBudgets`.
Tách bạch nguồn đo qua `MeasurementSource {hostHeadless, realDevice}` —
đây là điểm mấu chốt trả lời đúng "Benchmark device/emulator policy rõ":
1 policy đòi `realDevice` mà chỉ có số đo `hostHeadless` thì FAIL thẳng
(`wrongSource`), không bao giờ âm thầm chấp nhận số đo host thay bằng
chứng device.

**"Vi phạm budget fail đúng stage, report actionable"**: `tool/performance_budget_check.dart`
(`check`/`snapshot`, cùng convention split với `tool/api_compatibility.dart`)
in ra từng measured value + từng violation kèm `kind` cụ thể
(`missingMeasurement`/`wrongSource`/`staleMeasurement`/`budgetExceeded`/`regression`)
và exit code 1 — CI fail đúng ngay bước này, message đủ để biết sửa gì mà
không cần đọc log dài.

**"Reproducible và có baseline"**: metric `hostHeadless` KHÔNG bịa số —
gọi thẳng `runPooled`/`runUnpooled` có sẵn từ `tool/object_pool_benchmark.dart`
(FEAT-48). `object_pool_allocation_reduction_percent` deterministic tuyệt
đối (150 vs 6000 allocation với scenario mặc định = 97.5%, không phụ
thuộc tốc độ máy) — policy đặt sàn 90% cho số này. `object_pool_pooled_elapsed_us`
phụ thuộc tốc độ host nên chỉ đặt trần rất rộng (2s, để bắt regression
kiểu O(n²) thật sự) + `regressionTolerancePercent: 200` so với baseline
để tránh flaky vì nhiễu máy.

**"Smoke device thật xác nhận metric không chỉ pass trên host"** — làm
THẬT, không giả lập: `snapshot --device=<id>` tự chạy
`example/integration_test/app_boot_test.dart` trên đúng device đó và đo
wall-clock thật bằng `Stopwatch` từ tiến trình `flutter test` con. Đã chạy
thật trên Pixel 7 Pro (S24U không kết nối được lúc chạy, fallback đúng
quy ước đã ghi trong memory) → `example_app_boot_wall_ms = 32318ms`,
ghi vào `tool/performance_budget_baseline.json` kèm `recordedAtMs` thật.
`check` (không có `--device`, đúng tình huống CI không có thiết bị) dùng
lại giá trị `realDevice` đã commit này — nhưng KHÔNG tin mãi mãi: policy
đặt `maxAgeMs = 30 ngày`, quá hạn thì tự thành `staleMeasurement` (fail),
ép phải chạy lại smoke test định kỳ thay vì để 1 số đo device cũ mãi mãi
pass.

**Không thêm UI mới** — thuần tooling/CLI, không có widget nào để xét
animation/accessibility/reduced-motion; tiêu chí này vacuously đúng, đánh
dấu theo đúng cách FEAT-84 đã làm cho task không đụng UI.

Verify:
- `flutter test test/core/utils/performance_budget_test.dart`: 17/17 pass
  (mọi kind violation, JSON round-trip, fallback an toàn trên map thiếu
  field).
- `flutter test test/tool/performance_budget_check_test.dart`: subprocess
  thật chạy `dart run tool/performance_budget_check.dart` — pass trên
  chính policy/baseline thật của repo, và 4 case fixture temp-file
  (missingMeasurement, budgetExceeded, entry hỏng bị bỏ qua không crash,
  `snapshot` giữ nguyên metric `realDevice` cũ khi không truyền `--device`).
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: All tests passed (1975 test).
- `flutter test --exclude-tags slow` example/: All tests passed (97 test).
- `dart run tool/api_compatibility.dart snapshot` rồi `check` → `unchanged`
  (đã export `performance_budget.dart` trong `lib/roy_casual_kit.dart`,
  CHANGELOG.md có mục 0.2.0 tương ứng).
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- `dart run tool/performance_budget_check.dart check` chạy tay lần cuối
  trên repo thật: PASS cả 3 policy, số đo `realDevice` là số thật từ
  Pixel 7 Pro vừa smoke ở trên.

Tự chấm: 9.5/10. Điểm cao vì cả 2 nguồn đo đều là số THẬT (allocation
count deterministic từ benchmark có sẵn, wall-clock thật từ 1 lần chạy
integration test thật trên Pixel 7 Pro) chứ không phải placeholder giả —
đúng tinh thần "honest headless-vs-device" đã lặp lại xuyên suốt session
này (FEAT-68/69). Trừ 0.5 vì `object_pool_pooled_elapsed_us` vẫn là 1
timing-based metric có thể nhiễu theo máy dù đã nới trần/tolerance rộng —
không có cách nào loại nhiễu 100% khi benchmark chạy trên CI runner chia
sẻ tài nguyên.

