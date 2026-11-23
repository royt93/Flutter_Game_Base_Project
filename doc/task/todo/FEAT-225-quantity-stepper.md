---
id: FEAT-225
title: "QuantityStepper: nút +/- chọn số lượng có min/max, giữ để tăng nhanh"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

`shop_item_card` chưa có chọn số lượng; dùng được trong shop, crafting, inventory.

## Phạm vi đề xuất

- `QuantityStepper(value, onChanged, min, max, step)`: `min <= max`, `step > 0` (kiểm bằng `ArgumentError`), nút bị vô hiệu ở biên, giữ nút để tăng nhanh (timer huỷ khi dispose/rời khỏi cây, tăng tốc dần có giới hạn), không bao giờ vượt biên.
- Semantics: dạng adjustable (increment/decrement) để screen reader tăng/giảm; hiển thị giá trị qua `fmtNum` (locale).
- Test: giữ nhanh dừng khi thả, không rò timer sau dispose, biên, RTL đặt nút đúng phía.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Cho gõ số trực tiếp hay chỉ +/-. Đề xuất: chỉ +/-.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `QuantityStepper` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `QuantityStepper` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Test timer giữ-để-tăng: dừng khi thả, không rò sau dispose (`tester.pumpWidget(SizedBox())` rồi kiểm không còn timer), tăng tốc có trần.
- [ ] 4. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 5. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 6. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 7. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 8. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 9. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 10. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] Không bao giờ vượt `[min, max]`.
- [ ] Semantics adjustable (increment/decrement).
- [ ] `min > max` hoặc `step <= 0` là `ArgumentError`.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
