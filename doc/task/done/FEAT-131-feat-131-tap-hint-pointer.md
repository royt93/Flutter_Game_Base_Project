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
- [x] **Unit test**: `tapHintPointerOffsetAt` (tap nhấp nhô rồi về chỗ cũ, vuốt trượt từ A sang B rồi nghỉ); validate đúng một trong `targetKey`/`position`, `swipeTo` bắt buộc cho vuốt và không hợp lệ cho chạm, `size` dương hữu hạn.
- [x] **Widget test**: Đặt theo `targetKey` và theo `position`; `targetKey` chưa gắn thì không render và không lỗi; `visible = false` ẩn; vuốt di chuyển về `swipeTo`; chạm xuyên qua tới widget bên dưới; Reduced Motion giữ con trỏ tĩnh; dispose giữa chừng không lỗi. Con trỏ là `ExcludeSemantics` nên không đọc lặp.
- [x] **Showcase test**: Bật/tắt gợi ý, chuyển chạm/vuốt, tap nút mục tiêu vẫn nhận được khi có con trỏ phủ lên.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Một `AnimationController` điều khiển cả con trỏ và vòng sóng, vẽ trong `RepaintBoundary`; dừng khi ẩn hoặc Reduced Motion, dispose khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
