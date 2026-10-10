---
id: FEAT-115
title: StaggeredAnimatedGrid — Lưới card danh mục/shop hiệu ứng gợn sóng cascade
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Khi mở màn hình Shop, chọn nhân vật, danh mục vật phẩm, hiển thị lưới tĩnh rất khô cứng; hiệu ứng xuất hiện gợn sóng tuần tự tạo cảm giác cao cấp.

## Đề xuất phạm vi
Widget StaggeredAnimatedGrid tự động tính toán delay từng ô theo hàng/cột (offset theo ma trận i, j), làm các thẻ bài trượt nảy vào vị trí với độ trễ 40ms.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán stagger delay cho từng item index theo crossAxisCount.
- [ ] **Widget test**: Mount grid 6 phần tử, pump thời gian và kiểm tra các phần tử xuất hiện lần lượt từ trên xuống dưới.
- [ ] **Integration test**: Mở tab Shop trên thiết bị thật, quan sát các thẻ vật phẩm nảy vào vị trí mượt mà 60fps.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Hỗ trợ tắt stagger khi reducedMotion bật, tự ngắt controller sau khi toàn bộ grid đã xuất hiện.
