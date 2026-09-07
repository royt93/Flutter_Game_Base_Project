---
id: ENH-16
title: "CHANGELOG.md chỉ có entry 0.1.0 gốc, version chưa bump dù 62 task đã xong"
type: enhance
priority: P2
effort: S (cần quyết định version scheme trước — xem Phụ thuộc)
verified: true
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Hiện trạng
`CHANGELOG.md` chỉ có 1 entry gốc `0.1.0`. `pubspec.yaml` version vẫn
`0.1.0`. Toàn bộ 62 task (12 BUG, 12 ENH, 30 FEAT, 8 IDEA) hoàn thành trong
session vừa qua chưa được phản ánh vào changelog/version — `pana`/pub.dev
score chấm điểm changelog-khớp-version, hiện tại sẽ bị trừ điểm.

## Phụ thuộc
Cần quyết định version scheme trước khi viết changelog: version 1 lần (vd
`0.2.0`) tóm tắt toàn bộ, hay chia theo nhóm task lớn (vd `0.2.0` cho core
services, `0.3.0` cho widget kit mở rộng, v.v.)? Đây là quyết định phạm vi
sản phẩm, không phải kỹ thuật thuần — cần hỏi ý kiến trước khi làm.

## Đề xuất (mặc định nếu không có ý kiến khác)
1 entry `0.2.0` tóm tắt theo nhóm: core services mới, widget kit mở rộng
(37 widget), Flame starter template + FlameTrackedOverlay, bug fix đáng chú ý
(BUG-01 đến BUG-13). Bump `pubspec.yaml` version khớp.

## Acceptance criteria
- [x] `CHANGELOG.md` có entry mới phản ánh đúng công việc đã làm.
- [x] `pubspec.yaml` version bump khớp entry mới nhất.

## Quyết định
Theo đúng đề xuất mặc định: 1 entry `0.2.0` tóm tắt theo nhóm (core services
mới, widget kit 40-widget, Flame starter + FlameTrackedOverlay, bug fix đáng
chú ý). `pubspec.yaml` bump `0.1.0` → `0.2.0`, description + README cập nhật
số lượng widget (39 → 40, do IDEA-10/`LeaderboardList` thêm cùng lúc).
