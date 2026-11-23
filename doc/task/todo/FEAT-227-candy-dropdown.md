---
id: FEAT-227
title: "CandyDropdown<T>: ô chọn rút gọn (mở bottom sheet) thay cho picker tự ghép"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog. ĐÃ SỬA cùng ngày: bản đầu ghi sai là kit thiếu checkbox"
---

## Đính chính (quan trọng)

Bản đầu của task này (và câu hỏi gửi owner) nói kit "không có checkbox". SAI: `lib/presentation/widgets/common/candy_radio_group.dart` đã có `CandyCheckboxTile` (FEAT-113; showcase dòng "CandyRadioGroup & CandyCheckboxTile"). Phần checkbox bị BỎ khỏi phạm vi. Lỗi tìm kiếm: grep `Checkbox` theo `lib` ra 1 file nhưng bản quét đầu dùng mẫu `checkbox\|CandyCheckbox` trong `grep -E` nên không khớp. Bài học: kiểm lại bằng grep không phân biệt dạng, trước khi khẳng định "kit không có".

## Cái còn thiếu thật

Không có `CandyDropdown`. Example tự ghép trong `example/lib/screens/settings_screen.dart` (`_pickLanguage`): `showCommonBottomSheet` + `CommonListTile` cho từng mục + dấu chọn. Mỗi app sẽ lặp lại đoạn đó.

## Phạm vi đề xuất

- `CandyDropdown<T>(items, value, onChanged, placeholder?)`: ô hiển thị giá trị chọn, bấm mở `showCommonBottomSheet` liệt kê mục (tái dùng `CommonListTile`), dấu chọn ở mục hiện tại, disabled, giá trị không thuộc `items` hiển thị placeholder (không ném).
- `items` rỗng: chốt khi làm (đề xuất: ô disabled + placeholder, không ném).
- Semantics: button có nhãn + giá trị hiện tại; vùng chạm >= 44dp; RTL; text scale 2x.
- Cập nhật `settings_screen.dart` để dùng widget mới, chứng minh thay được mã tự ghép (bớt mã trùng).

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Dropdown có tìm kiếm (`candy_search_bar` đã có) khi nhiều mục hay không. Đề xuất: không ở bản đầu.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `CandyDropdown<T>` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `CandyDropdown<T>` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Chốt hành vi `items` rỗng (đề xuất: disabled + placeholder).
- [ ] 4. Thay `_pickLanguage` trong `example/lib/screens/settings_screen.dart` bằng widget mới (làm SAU FEAT-224 nếu cả hai cùng mở file này).
- [ ] 5. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 6. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 7. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 8. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 9. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 10. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 11. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] Giá trị không thuộc `items` hiển thị placeholder, không ném.
- [ ] Mở bottom sheet, chọn xong đóng và gọi `onChanged`.
- [ ] `settings_screen_test` vẫn pass.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
- `cd example && flutter test test/settings_screen_test.dart`
