---
id: FEAT-228
title: "StatBar: thanh chỉ số ngang (HP, mana, XP) có nhãn, giá trị/tối đa, hiệu ứng trễ khi mất"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Đã đọc để chốt ranh giới (không trùng): `EnergyBar` là hàng icon (tim) theo `currentEnergy/maxEnergy`, `ProgressBarStars` là thanh tiến độ có sao + pháo, `CircularProgressRing` là vòng tròn. Chưa có thanh chỉ số ngang tổng quát cho HP/mana/XP.

## Phạm vi đề xuất

- `StatBar(value, max, label?, color, showValue)`: `max > 0`, `value` kẹp trong [0, max] (kiểm bằng `ArgumentError` cho `max`), thanh "trễ" (phần vừa mất giảm chậm sau thanh chính) và phần hồi, tôn trọng reduced motion (không hiệu ứng thì nhảy thẳng).
- Semantics: đọc "<nhãn> <value> trên <max>", không đọc từng bước hoạt ảnh; hiển thị số qua `fmtNum`.
- Test: kẹp biên, giá trị = 0 và = max, đổi giá trị liên tiếp, RTL (thanh đầy từ bên phải), text scale 2x.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Có phiên bản dọc (cho HUD cạnh màn) hay chỉ ngang. Đề xuất: ngang trước.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `StatBar` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `StatBar` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Test kẹp `value` về [0, max], `max <= 0` là `ArgumentError`, đổi giá trị liên tiếp, thanh "trễ" không nhảy ngược; reduced motion nhảy thẳng.
- [ ] 4. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 5. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 6. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 7. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 8. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 9. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 10. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] Semantics đọc "<nhãn> <value> trên <max>", không đọc từng bước hoạt ảnh.
- [ ] RTL đầy từ bên phải.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
