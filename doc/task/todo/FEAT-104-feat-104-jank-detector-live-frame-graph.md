---
id: FEAT-104
title: JankDetector & Live Frame Graph cho Debug QA Overlay
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Partner yêu cầu kiểm soát hiệu năng gắt gao; dev cần nhìn thấy biểu đồ frame time thực tế ngay trên màn hình game để bắt kịp thời điểm bị drop frame.

## Đề xuất phạm vi
Widget LiveFrameGraph hiển thị thanh biểu đồ 60/120 FPS gần nhất, phân loại frame xanh/vàng/đỏ (dưới 16.6ms / trễ >33ms) tích hợp tab mới trong DebugQaOverlay.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra phân loại FrameTiming thành normal/slow/jank và bộ đệm bounded 100 frame gần nhất.
- [ ] **Widget test**: Cung cấp chuỗi FrameTiming giả lập, kiểm tra widget vẽ đúng số lượng cột biểu đồ và cảnh báo khi có jank.
- [ ] **Integration test**: Bật QA overlay trên TECNO, vuốt cuộn màn hình và quan sát biểu đồ biến thiên theo thời gian thực.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Chỉ hoạt động trong kDebugMode/kProfileMode, tự ngắt callback khi đóng panel.
