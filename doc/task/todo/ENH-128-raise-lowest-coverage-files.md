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

- [ ] 1. Chạy lại `flutter test --coverage ...`, lập danh sách dòng chưa phủ của 9 file trên (`genhtml` hoặc đọc `lcov.info`).
- [ ] 2. Với mỗi dòng chưa phủ: viết test cho nhánh thật, hoặc đánh dấu bỏ qua có lý do nếu là mã không thể tới (ghi lý do ngắn), không viết test vô nghĩa chỉ để tăng số.
- [ ] 3. Mutation check cho test mới; chạy lại đo, ghi trước/sau từng file.
- [ ] 4. Ghi baseline (tổng và theo thư mục) vào `docs/qa/` kèm lệnh và ngày; KHÔNG thêm cổng độ phủ vào CI (owner đang giảm gánh CI).
- [ ] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] 9 file trên đạt >= 90% hoặc có lý do ghi rõ từng dòng còn lại.
- [ ] Baseline 97.0% (hoặc số mới) được ghi vào docs/qa với lệnh tái lập.
- [ ] Không thêm cổng CI.

## Lệnh kiểm chứng nhanh

- `flutter test --coverage --exclude-tags slow test/core test/widget/common test/tool test/presentation`
