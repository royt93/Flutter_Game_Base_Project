---
id: FEAT-229
title: "DialogueBox: hộp hội thoại NPC/hướng dẫn, chữ hiện dần, chọn câu trả lời"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Quét `lib`: không có typewriter/dialogue. Dùng cho game phiêu lưu, visual novel nhẹ, tutorial có nhân vật (bổ sung cho `tutorial_sequence`, vốn là spotlight trên UI thật).

## Rủi ro đã nêu

Phạm vi dễ phình (kịch bản, nhánh, nhân vật). Giữ ở mức một hộp hiển thị: nội dung và logic nhánh do app cấp.

## Phạm vi đề xuất

- `DialogueBox(speaker?, text, onNext, choices?)`: chữ hiện dần theo tốc độ, bấm một lần để hiện hết, bấm lần hai để tiếp; `choices` 0-4 nút; reduced motion thì hiện nguyên câu ngay.
- Semantics: screen reader đọc nguyên câu một lần (không đọc từng ký tự); nút tiếp/chọn có nhãn; RTL; text scale 2x không tràn (hộp tự cao lên/cuộn).
- Ký tự Unicode tổ hợp/emoji: cắt theo grapheme cluster, không cắt giữa ký tự (dùng `characters` có sẵn trong Flutter).
- Test: tiến trình chữ, bỏ qua, chọn câu trả lời, câu rỗng, câu rất dài, dispose không rò timer.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Có ảnh chân dung nhân vật không. Đề xuất: slot widget tuỳ chọn do app cấp, kit không giữ ảnh.
