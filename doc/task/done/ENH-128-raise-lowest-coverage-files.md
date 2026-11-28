---
id: ENH-128
title: "Nâng độ phủ các file thấp nhất lên >= 90% và ghi baseline độ phủ 97.0% (không thêm cổng CI)"
type: enhancement
layer: test
priority: P4
effort: S
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23, `flutter test --coverage` trên 4137 test host)

Tổng dòng 97.0% (21272/21941, 280 file): `lib/core` 97.9%, `widgets/common` 96.8%, `widgets` 89.7%, `presentation/game` 89.0%. File ≥ 40 dòng phủ thấp nhất: `scratch_card.dart` 80.5%, `staggered_animated_grid.dart` 82.4%, `pressable_scale.dart` 84.3%, `roy_game.dart` 85.3%, `neon_dialog.dart` 87.2%, `offline_earnings_popup.dart` 87.5%, `pooled_particle_burst.dart` 87.7%, `golden_shimmer_text.dart` 89.1%, `card_flip_3d.dart` 89.4%.

Đo bằng `flutter test --coverage` chỉ trên `test/core test/widget/common test/tool test/presentation` (không gồm `example/`, không gồm thư mục golden). Độ phủ dòng không chứng minh đúng hành vi; task này chỉ lấp dòng chưa chạy.

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Chạy lại `flutter test --coverage ...`, lập danh sách dòng chưa phủ của 9 file trên (`genhtml` hoặc đọc `lcov.info`).
- [x] 2. Với mỗi dòng chưa phủ: viết test cho nhánh thật, hoặc đánh dấu bỏ qua có lý do nếu là mã không thể tới (ghi lý do ngắn), không viết test vô nghĩa chỉ để tăng số.
- [x] 3. Mutation check cho test mới; chạy lại đo, ghi trước/sau từng file.
- [x] 4. Ghi baseline (tổng và theo thư mục) vào `docs/qa/` kèm lệnh và ngày; KHÔNG thêm cổng độ phủ vào CI (owner đang giảm gánh CI).
- [x] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] 9 file trên đạt >= 90%; chưa phủ có lý do trong `docs/qa/coverage_baseline.md`.
- [x] Baseline 97.0% (hoặc số mới) được ghi vào docs/qa với lệnh tái lập.
- [x] Không thêm cổng CI.

## Lệnh kiểm chứng nhanh

- `flutter test --coverage --exclude-tags slow test/core test/widget/common test/widget/pressable_scale_test.dart test/widget/neon_dialog_test.dart test/tool test/presentation`

## Kết quả thực hiện (2026-11-28)

- Coverage trước task, đo lại bằng command scope ở dưới: 97.44% (21,547/22,112), 283 file. Tất cả 9 file mục tiêu, danh sách dòng chưa phủ, theo thư mục và lệnh nằm trong `docs/qa/coverage_baseline.md`.
- Test mới/chỉnh có mục tiêu: ScratchCard (+ reset, pointer ownership/cancel, painter update, validation grid; lên 100%), StaggeredAnimatedGrid (+ validation toàn bộ config, đổi delay trước Timer fire), PressableScale (+ pointer cancel, đưa lên 100%), NeonDialog (+ overlay blocks semantics, đưa lên 100%), CardFlip3D (+ controller idempotency, controller replacement/curve/timings/axis, reduced motion in-flight, vertical back, lên 99.3%), GoldenShimmerText (+ update state), PooledParticleBurst (+ validation/reduced-motion queued unmount), OfflineEarningsPopup (+ validation labels và update coins với/không reduced motion), RoyGame (+ spriteLoader fake in-memory, direction getter, validation speed, lên 91.4%).
- Coverage sau: 97.46% (21,550/22,112), 283 file; `core` 97.95%, `widgets/common` 97.31%, other widgets 98.79%, `presentation/game` 92.55%. Cả 9 target đạt ngưỡng: 90.9%–100%. Scoped coverage suite cuối 4294 pass.
- Mutation probes: 3/3 bị bắt: RoyGame bỏ `setSprites`, CardFlipController bỏ notify, NeonDialog overlay bỏ `BlockSemantics`. Hai mutation sống: stagger-delay Timer replacement và ScratchCard brushWidth repaint; ghi rõ trong coverage baseline, không nhận là regression đã bảo vệ. Các nhánh validation/transition còn thiếu khác đã rà trong `docs/qa/coverage_baseline.md`, chủ yếu constructor delegation/framework init-failure, painter delegate private, hoặc Tiled asset loading.
- Cổng cuối: `flutter analyze` root/example sạch; command nghiệm thu `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4261 pass; `api_compatibility` unchanged; 5 quality gates sạch. Scoped coverage command 4294 pass vì cộng thêm `test/widget/pressable_scale_test.dart` và `test/widget/neon_dialog_test.dart`, nằm ngoài các thư mục nghiệm thu chuẩn.
- Không thêm coverage gate CI.
