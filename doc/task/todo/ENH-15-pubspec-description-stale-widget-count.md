---
id: ENH-15
title: "pubspec.yaml description nói \"21-widget\" nhưng barrel đã export 37"
type: enhance
priority: P3
effort: S
verified: true
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Hiện trạng
`lib/presentation/widgets/common/common_widgets.dart` hiện có 37 dòng
`export`. `pubspec.yaml`'s `description` (hiển thị trên pub.dev) vẫn ghi con
số cũ từ lần audit đầu ("21-widget"), đánh giá thấp package so với thực tế.

## Đề xuất
Cập nhật `description` trong `pubspec.yaml` với số widget/service thực tế
hiện tại (đếm lại `export` trong barrel + số core service trong `lib/core/`).
Kiểm tra README.md có cùng con số cũ ở đâu khác không, sửa luôn nếu có.

## Acceptance criteria
- [ ] `pubspec.yaml` description khớp số liệu thật.
- [ ] README.md (nếu có nhắc số liệu tương tự) cũng khớp.
