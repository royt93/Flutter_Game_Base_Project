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
