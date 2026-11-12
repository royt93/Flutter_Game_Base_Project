---
id: ENH-105
title: "Cho phép ghi đè chuỗi tiếng Anh hard-code ở 3 panel"
type: enhancement
layer: lib/widgets/common
priority: P3
effort: S
source: "Audit UI 2026-11-12"
---

## Đã làm
Thêm tham số tên tuỳ chọn, mặc định giữ nguyên tiếng Anh, theo đúng pattern có sẵn của các panel này:
- `OutboxConflictSummaryPanel`: `emptyLabel`, `remoteLabel`
- `SessionTimelineInspector`: `durationLabel`
- `SupportDiagnosticsCard`: `appVersionLabel`, `truncatedLabel`, `privacyNote`, `sectionErrorsLabel` (callback đếm)

Giá trị rỗng bị từ chối bằng `ArgumentError` như các nhãn khác. Test: `test/widget/common/enh105_label_overrides_test.dart`.

## Không làm
`live_frame_graph` (chỉ dùng trong `DebugQaOverlay`, dev-only). Không thêm key vào `AppTranslations`: package để consumer tự localize qua tham số.

## Lưu ý API
Constructor đổi chữ ký (thêm tham số tên tuỳ chọn) nên `api_snapshot.json` được regenerate; không phá consumer hiện có.
