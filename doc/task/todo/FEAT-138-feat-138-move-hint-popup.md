---
id: FEAT-138
title: MoveHintPopup — Popup gợi ý nước đi khi người chơi bị kẹt trong màn puzzle
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Live-Ops Expansion (Wave 9)
---

## Vì sao cần
Khi người chơi dừng quá lâu mà chưa tìm được nước đi, game cần gợi ý hành động kế tiếp: đổi chỗ hai ô, dùng booster, hoặc xem hướng dẫn ngắn. Popup giúp giảm bỏ cuộc mà vẫn để thuật toán tìm nước đi và chính sách gợi ý do game caller kiểm soát.

## Đề xuất phạm vi
Widget `MoveHintPopup` hiển thị:
- Icon/emoji của loại gợi ý (`swap`, `use booster`, `goal hint`) và tiêu đề/mô tả caller truyền sẵn.
- Tùy chọn tọa độ nguồn/đích (`Offset? from`, `Offset? to`) hoặc nội dung `Widget? hintContent` để minh họa hành động; không tự phân tích board state.
- Nút “Got it” / “Try hint” gọi callback caller-owned `onDismiss` hoặc `onHintTap`.
- Có thể hiển thị count số lượt gợi ý còn lại; khi count = 0 có thể ẩn nút gợi ý hoặc gọi `onEmptyHintTap`.
- Dùng `NeonDialog.overlay`/`NeonDialog.show` in-tree để tương thích Flame `GameWidget`; Reduced Motion bỏ entrance pop.
- Không phụ thuộc vào IAP hoặc ads; caller tự xử lý các lựa chọn “mua thêm/xem quảng cáo” nếu có.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate tiêu đề không rỗng, count không âm, các tọa độ hữu hạn; kiểm tra clamp vị trí minh họa vào viewport nếu có.
- [ ] **Widget test**: Nút hint/dismiss gọi đúng callback; count=0 khóa/ẩn hint action; Reduced Motion; semantics đọc tiêu đề, hướng dẫn và số lượt còn.
- [ ] **Integration test (Device)**: Smoke trên Pixel 7 Pro: mở popup từ showcase, kích hoạt hint, đóng popup và xác nhận callback.
- [ ] **Golden test**: So khớp panel/icon ở light/dark, RTL và textScale 1.0/1.4.
- [ ] **Interruption test**: Đóng dialog hoặc app pause trong entrance animation, kiểm tra không leak controller/overlay; resume không mở popup ngoài ý muốn.
- [ ] **Network conditioning test**: N/A (thuần presentation, nội dung hint đã được caller tính sẵn).
- [ ] **Memory leak & profiling test**: Dùng MemoryLifecycleWatchdog kiểm tra overlay/painter/controller được dispose sau dismiss.
- [ ] **Frame rate / Jank test**: Thu FrameTiming cho open/dismiss/animation, báo p50/p95/p99 và jank count.
- [ ] **IAP & Ad mediation test**: N/A trong widget kit; caller chịu trách nhiệm kiểm thử store/ad nếu hành động hint nối sang purchase/ad mediation.

## Hiệu năng & Animation
- [ ] Dialog render như in-tree overlay, chỉ tạo animation controller khi hiển thị.
- [ ] Sustained 60 FPS benchmark: đo theo workload định sẵn nếu cần.
