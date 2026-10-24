---
id: IDEA-83
title: "Audit accessibility semantics for Flame HUD overlays"
type: idea
layer: presentation/accessibility
priority: P2
effort: S
status: speculative
---

## Giả thuyết

Game HUD có thể render visual state mà screen reader không nhận được, dù package đã có `GameAccessibilityAnnouncer` và `FlameTrackedOverlay`.

## Ý tưởng

Chỉ audit semantics end-to-end cho một HUD use case. Xác định liệu Flutter semantics overlay native hiện có đủ hay có gap cụ thể; không đề xuất wrapper mới nếu chưa chứng minh cần.

## Discovery gate

- [ ] Chọn HUD hiện có/consumer case và dump semantic tree.
- [ ] Kiểm tra label, value, action, focus order, update announcement frequency.
- [ ] Xác minh TalkBack/VoiceOver behavior trên platform phù hợp.
- [ ] Chỉ tạo feature task nếu phát hiện gap reproducible không giải quyết được bằng API native.

## Prompt loop feature

Đọc `GameAccessibilityAnnouncer`, `FlameTrackedOverlay`, HUD widgets và accessibility audit tests. Thực hiện audit trước, không thêm code/API trong phase này. Ghi semantic tree và device/tool evidence; tránh announcement mỗi game tick hoặc focus stealing. Nếu có defect, tạo BUG/FEAT task riêng để duyệt. Chấm độ tin cậy/evidence; device check là deliverable audit, không phải smoke của implementation. Không commit/push thay đổi code khi chưa có approval.

## Kết quả source audit (2026-10-24)

- `GameAccessibilityAnnouncer` phát announcement theo `GameEventBus`, hỗ trợ localized message và throttle theo category; package không gọi platform API trực tiếp (`lib/core/game_accessibility_announcer.dart:18-28,48-69`).
- `FlameTrackedOverlay` đặt Flutter child trong Stack để theo dõi world position; source không tự gắn `Semantics` cho child (`lib/presentation/widgets/flame_tracked_overlay.dart:31-64`). Consumer vẫn sở hữu overlay child và semantics của nó.
- Test suite có unit/widget tests cho announcer và accessibility audit/common widgets, nhưng chưa thấy game-specific semantic-tree test hay evidence TalkBack/VoiceOver cho `GameDemoScreen` HUD.
- Đây là gap evidence, chưa phải bug đã xác nhận: semantic behavior phụ thuộc widget child/consumer configuration.

## Kết luận / next evidence

Chưa có device accessibility observation trong discovery này; không được kết luận screen reader đang fail. Việc cần tiếp theo là audit semantic tree của HUD đang tồn tại và, nếu consumer yêu cầu, kiểm tra TalkBack trên Android. Chỉ tạo BUG/FEAT nếu có missing label/action/focus hoặc announcement issue tái hiện. Không thêm wrapper/API trước evidence.

## Quyết định

Audit hoàn tất và chuyển sang `done`. Phát hiện hai nút FAB icon-only thiếu tooltip/semantics ở `example/lib/screens/game_demo_screen.dart:462-489`; người dùng duyệt tạo `BUG-102` để sửa. Không thêm API/wrapper package.
