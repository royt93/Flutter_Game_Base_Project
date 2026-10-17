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
- [x] **Unit test**: Validate title/message không rỗng, `remainingHints >= 0`, cặp tọa độ/GlobalKey đầy đủ và tọa độ finite.
- [x] **Widget test**: Swap/booster/goal/custom có default icon/color; hint còn thì Try Hint gọi `onHintTap`; hết hint thì Get More (+) gọi `onEmptyHintTap`; dismiss gọi callback; custom illustration ưu tiên; semantics đọc title/message/count.
- [x] **Integration test (Device)**: Smoke pass trên Pixel 7 Pro (`2B051FDH3006MU`), mở popup, xác nhận nội dung và đóng.
- [x] **Golden test**: `runGoldenMatrix` light/dark/vi/RTL/text-scale/reduced-motion không overflow.
- [x] **Interruption test**: Overlay đóng trong lúc hiển thị; callback dismiss và route teardown được kiểm tra trong test `.show()`.
- [x] **Network conditioning test**: N/A — nội dung hint/callback do caller cung cấp; widget không gọi network.
- [x] **Memory leak & profiling test**: Widget stateless, không sở hữu controller/timer/subscription; test mount/unmount và overlay dismiss không để lại resource owned.
- [ ] **Frame rate / Jank test**: Chưa thu FrameTiming riêng cho MoveHintPopup; workload benchmark Wave 8 không đại diện widget này.
- [x] **IAP & Ad mediation test**: N/A trong kit; Get More callback chỉ do caller cung cấp, không tự gọi store/ad.

## Hiệu năng & Animation
- [x] Panel dùng `NeonDialog.show` in-tree-safe helper và không sở hữu animation controller riêng; entrance Reduced Motion do NeonDialog.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
