---
id: FEAT-236
title: "FeedbackSheet: bảng góp ý (loại, văn bản, tuỳ chọn đính kèm chẩn đoán), kit chỉ lo UI + callback"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm (bằng đọc code)

- `DiagnosticsExportBundle.build(...)` gom chẩn đoán vào một `Map` (có cấu hình đã lọc, nhật ký gần đây) và có `sign(...)`. Doc của nó cảnh báo một nguồn đầu vào "không có redaction nào" và có nhánh `errors['config'] = 'redact failed'`: dữ liệu đính kèm KHÔNG mặc định an toàn để gửi đi.
- `ConsentStateService` có sẵn (consent người dùng). Kit không có backend; chỉ có seam.
- Grep feedback/bug_report/report_problem trong `lib`: không có.

## Rủi ro đã nêu và ràng buộc

Gửi dữ liệu người dùng đi nơi khác là việc nhạy cảm. Ràng buộc: widget KHÔNG gửi gì; nó chỉ gọi `onSubmit(FeedbackSubmission)` do app cấp. Đính kèm chẩn đoán mặc định TẮT, người dùng bật thủ công và xem được nội dung tóm tắt trước khi gửi; nếu app có `ConsentStateService` mà consent chưa cho phép thì ô đính kèm bị vô hiệu kèm lý do. Không log nội dung góp ý.

## Phạm vi đề xuất

- `FeedbackSheet` (qua `showCommonBottomSheet`): chọn loại (lỗi/ý tưởng/khác, danh sách do app cấp, 1-5 loại), ô văn bản (`CandyTextField`, giới hạn độ dài, tối thiểu 1 ký tự sau trim), công tắc đính kèm chẩn đoán (chỉ hiện khi app cấp `diagnosticsBuilder`), nút Gửi (vô hiệu khi rỗng, chặn bấm đúp bằng `async_action_guard`), trạng thái đang gửi/thành công/lỗi (`SdkResult` do `onSubmit` trả).
- Test: nút Gửi rỗng bị vô hiệu, bấm đúp chỉ gửi một lần, `onSubmit` thất bại hiển thị lỗi và cho gửi lại, không đính kèm khi công tắc tắt, consent chưa cho phép thì công tắc vô hiệu.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape @1x text; 568x320 @2x text).
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: semantics đúng, vùng chạm >= 44-48dp, RTL, `tool/accessibility_audit_check.dart` pass.
- Invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `FeedbackSheet` (3-5 dòng) trong "Kết quả thực hiện" trước khi code.
- [ ] 2. Viết `FeedbackSheet` + export trong `common_widgets.dart` + `ArgumentError` cho invariant.
- [ ] 3. Chốt kiểu `FeedbackSubmission(category, text, diagnostics?)` và `onSubmit -> Future<SdkResult<void>>` trong "Kết quả thực hiện".
- [ ] 4. Đọc `diagnostics_export_bundle.dart` và `consent_state_service.dart`; ghi cách app đính kèm an toàn (đã redact) vào dartdoc, và chốt câu chữ cảnh báo về dữ liệu chưa redact.
- [ ] 5. Test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0; mutation check (bỏ logic chính, test đỏ).
- [ ] 6. Fixture `runViewportSweep`; thêm vào `widget_showcase_screen.dart`; `cd example && flutter test` pass.
- [ ] 7. Accessibility: semantics, vùng chạm, `dart run tool/accessibility_audit_check.dart`.
- [ ] 8. Commit + push widget và test (chưa golden); `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, CHỈ chép PNG của widget này vào `test/widget/goldens/goldens/`, commit + push.
- [ ] 9. API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 10. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/` (kiểm staged diff trước commit).

## Tiêu chí nghiệm thu

- [ ] Không gửi gì khi người dùng chưa bấm Gửi; kit không có mã mạng.
- [ ] Đính kèm chẩn đoán mặc định tắt và có bản xem trước.
- [ ] Bấm đúp chỉ gọi `onSubmit` một lần.
- [ ] Thất bại hiển thị lỗi và cho thử lại; văn bản người dùng không bị mất.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common test/core/consent_state_service_test.dart`
