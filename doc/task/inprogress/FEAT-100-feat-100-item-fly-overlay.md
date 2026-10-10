---
id: FEAT-100
title: ItemFlyOverlay — bay vật phẩm/icon đa năng từ toạ độ bất kỳ vào HUD/Slot
type: feature
priority: P0
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
CoinFlyOverlay chỉ hỗ trợ bay icon coin cố định. Partner cần bay thẻ bài, mảnh tướng, rương, ngọc từ phần thưởng rơi ra vào đúng vị trí slot kho đồ hoặc HUD.

## Đề xuất phạm vi
Widget ItemFlyOverlay.show(...) nhận sourceRect/GlobalKey, targetRect/GlobalKey, Widget Function(int index) builder, itemCount (1..10), đường cong quỹ đạo Bézier kèm pop scale và tự huỷ OverlayEntry khi bay xong.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [x] **Unit test**: Kiểm tra tính toán toạ độ nội suy Bézier curve và validate itemCount > 0, duration > Duration.zero.
- [x] **Widget test**: Mount overlay trong widget tree, pump duration bay tới đích, kiểm tra callback onComplete gọi đúng 1 lần và overlay tự dọn sạch.
- [x] **Integration test**: Bay 5 item từ popup nhận thưởng vào thanh Energy/Wallet trên thiết bị thật, FPS duy trì 60fps.

## Yêu cầu hiệu năng & Animation
- [x] **60 FPS & Resource cleanup**: Ticker tự dispose ngay khi hoàn tất, không rò rỉ OverlayEntry, dùng RepaintBoundary cho item bay.
