---
id: FEAT-230
title: "SwipeDirectionDetector: nhận biết vuốt 4 hướng (ngưỡng khoảng cách/tốc độ), logic thuần Dart + widget bọc"
type: feature
layer: lib/core + lib/presentation/widgets
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm (bằng đọc code)

`SwipeableActionTile` dùng `onHorizontalDragStart/Update/End` chỉ để KÉO MỞ hành động trên một hàng. Kit không có bộ nhận biết vuốt 4 hướng cho game (đổi ô, trượt puzzle, runner). Match-3 Lite trong example chỉ chạm-chọn.

## Chia việc (2 phần, làm lần lượt)

1. **Logic thuần Dart** `SwipeClassifier` (lib/core hoặc utils): nhận điểm đầu/cuối + thời lượng, trả `SwipeDirection?` (up/down/left/right) hoặc `null` nếu dưới ngưỡng. Tham số: `minDistance` > 0, `minVelocity` >= 0, `axisDominance` (tỉ lệ trục chính/phụ, để chéo mơ hồ trả `null`). Validate bằng `ArgumentError` (ENH-85). Test: 4 hướng, chéo mơ hồ, quá ngắn, quá chậm, NaN/vô cực bị từ chối; mutation check.
2. **Widget bọc** `SwipeDirectionDetector(onSwipe, child)` dùng `GestureDetector`/`Listener`, RTL không đảo hướng logic (vuốt trái là trái màn hình; tài liệu ghi rõ), không nuốt cuộn của cha khi nằm trong `ListView` (hoặc tài liệu giới hạn).

## Rủi ro đã nêu

Xung đột với back-swipe của hệ điều hành và cuộn; phải thử trên máy thật (S24U) ít nhất một lần: vuốt từ mép trái không bị mất. Tuỳ chọn: tích hợp vào Match-3 demo (vuốt đổi ô) thay chạm-chọn, nhưng owner nói demo sơ sơ nên để sau.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Phần 1 (logic): chốt tham số `minDistance`/`minVelocity`/`axisDominance` và giá trị mặc định trong dartdoc.
- [ ] 2. Viết test đỏ cho `SwipeClassifier`: 4 hướng, chéo mơ hồ, quá ngắn, quá chậm, NaN/vô cực; rồi cài đặt thuần Dart; `ArgumentError` cho tham số sai.
- [ ] 3. Mutation check phần logic.
- [ ] 4. Phần 2 (widget): `SwipeDirectionDetector(onSwipe, child)`; ghi rõ vuốt trái = trái màn hình kể cả RTL; test widget bằng `tester.fling/drag`.
- [ ] 5. Kiểm trên S24U (chọn theo model, không dùng simulator): vuốt từ mép trái không mất cử chỉ back; vuốt trong `ListView` không phá cuộn. Ghi kết quả; nếu không có máy, ghi rõ chưa kiểm.
- [ ] 6. Thêm vào `widget_showcase_screen.dart`, viewport sweep, golden qua workflow (xem Chuẩn widget).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Phần logic có test host đầy đủ và mutation check.
- [ ] Widget không nuốt cuộn của cha trong `ListView` (hoặc tài liệu ghi giới hạn).
- [ ] Đã kiểm hoặc ghi rõ CHƯA kiểm back-swipe trên thiết bị.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils test/widget/common`
