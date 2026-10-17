---
id: FEAT-131
title: TapHintPointer — Bàn tay chỉ nhấp nhô hướng dẫn người chơi bấm đúng chỗ
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 7)
---

## Vì sao cần
Onboarding trong game casual hiệu quả nhất khi có một bàn tay chỉ nhấp nhô đặt đúng vào nút hoặc ô cần bấm. `SpotlightOverlay` và `TutorialSequence` đã làm nổi bật vùng và hiển thị lời nhắc, nhưng chưa có con trỏ chuyển động chỉ rõ thao tác chạm hay vuốt.

## Đề xuất phạm vi
Widget `TapHintPointer` vẽ một bàn tay/con trỏ nhấp nhô lặp lại kèm vòng sóng lan toả tại vị trí mục tiêu:
- Hai kiểu gợi ý: chạm (nhấp nhô tại chỗ kèm vòng sóng) và vuốt (di chuyển giữa hai điểm theo `Offset`).
- Có thể gắn lên widget mục tiêu qua `GlobalKey` giống `SpotlightOverlay`, hoặc đặt bằng toạ độ cụ thể.
- Tự ẩn khi `visible = false`; không chặn thao tác của người chơi (`IgnorePointer`), tap xuyên qua tới widget bên dưới.
- Reduced Motion: hiển thị con trỏ tĩnh kèm vòng sóng cố định, không lặp animation.
- Widget thuần trình bày: caller quyết định khi nào hiện và khi nào ẩn, không tự theo dõi tiến trình onboarding.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra tính vị trí con trỏ theo hình chữ nhật của widget mục tiêu và nội suy đường vuốt giữa hai điểm.
- [ ] **Widget test**: `visible = false` không dựng animation; tap xuyên qua con trỏ tới widget bên dưới; Reduced Motion dừng lặp; controller được giải phóng khi unmount; semantics không đọc lặp gây nhiễu.
- [ ] **Showcase test**: Tích hợp vào showcase với nút bật/tắt gợi ý, cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap xuyên qua trên thiết bị vật lý thật, không dùng simulator.

## Hiệu năng & Animation
- [ ] Một `AnimationController` duy nhất điều khiển cả con trỏ và vòng sóng, vẽ trong `RepaintBoundary`.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
