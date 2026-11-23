---
id: FEAT-235
title: "StepProgressIndicator: chỉ báo nhiều bước có nhãn (hoàn thành/hiện tại/chưa)"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

`paginated_dots_indicator` là chấm chỉ trang (không nhãn, không trạng thái hoàn thành từng bước). Grep stepper/wizard/step_progress trong `lib` không ra gì. Cần ranh giới rõ: dots chỉ "đang ở trang mấy"; widget này chỉ "bước nào xong, bước nào đang làm, bước nào chưa", kèm nhãn.

## Phạm vi đề xuất

- `StepProgressIndicator(steps, currentIndex)`: `steps` là danh sách nhãn (2-7, ngoài đó `ArgumentError`), `currentIndex` trong `[0, steps.length]` (bằng `length` nghĩa là tất cả xong), nối giữa các bước, bước xong có dấu tích, bước hiện tại nổi bật, bước chưa xám.
- Màn hẹp: nhãn dài bị cắt một dòng (không tràn); semantics mỗi bước "<nhãn>, bước x trên n, hoàn thành/hiện tại/chưa"; RTL đảo hướng nối; reduced motion tắt hiệu ứng chuyển.

## Câu hỏi mở

Có bản dọc (danh sách) hay chỉ ngang. Đề xuất: ngang trước.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape @1x text; 568x320 @2x text).
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: semantics đúng, vùng chạm >= 44-48dp, RTL, `tool/accessibility_audit_check.dart` pass.
- Invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `StepProgressIndicator` (3-5 dòng) trong "Kết quả thực hiện" trước khi code.
- [ ] 2. Viết `StepProgressIndicator` + export trong `common_widgets.dart` + `ArgumentError` cho invariant.
- [ ] 3. Đọc `paginated_dots_indicator.dart` và ghi trong "Kết quả thực hiện" một đoạn khác biệt/ranh giới; nếu thấy chỉ cần thêm tham số cho dots thì dừng và báo owner thay vì tạo widget trùng.
- [ ] 4. Test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0; mutation check (bỏ logic chính, test đỏ).
- [ ] 5. Fixture `runViewportSweep`; thêm vào `widget_showcase_screen.dart`; `cd example && flutter test` pass.
- [ ] 6. Accessibility: semantics, vùng chạm, `dart run tool/accessibility_audit_check.dart`.
- [ ] 7. Commit + push widget và test (chưa golden); `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, CHỈ chép PNG của widget này vào `test/widget/goldens/goldens/`, commit + push.
- [ ] 8. API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 9. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/` (kiểm staged diff trước commit).

## Tiêu chí nghiệm thu

- [ ] `currentIndex` ngoài `[0, length]` bị từ chối (`ArgumentError`).
- [ ] Tất cả bước xong hiển thị đúng khi `currentIndex == length`.
- [ ] Nhãn dài không tràn ở 2.0x text.
- [ ] Semantics nêu đúng trạng thái từng bước.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
