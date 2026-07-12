# I4 — Predictive hint (gợi ý nhóm to nhất khi rảnh tay)

**Epic:** Gameplay depth · **SP:** 3 · **Pri:** P2 · **Deps:** none

## Mục tiêu
Sau X giây (mặc định 6s) không tap, tự động highlight (pulse glow) nhóm gem lớn nhất còn lại trên bàn, giúp người chơi bí nước đi không bị kẹt/chán.

## Vì sao
Board không refill, nhiều thời điểm bàn rối mắt khiến người chơi khó thấy nhóm lớn — gợi ý nhẹ nhàng giữ nhịp chơi mà không tự động chơi hộ (khác auto-solver).

## Acceptance criteria
- [ ] Timer đếm ngược 6s kể từ lần tap gần nhất (hoặc từ lúc màn bắt đầu), reset mỗi lần tap hợp lệ
- [ ] Hết 6s: quét toàn bàn tìm nhóm `>=2` ô lớn nhất bằng `findConnectedGroup` (không thêm thuật toán mới, tái dùng logic đã có trong `lib/logic/pop_detector.dart`)
- [ ] Highlight nhóm tìm được bằng hiệu ứng pulse/glow nhẹ trong vài giây, không chặn input
- [ ] Tap vào bất kỳ đâu trong lúc đang highlight: tắt highlight ngay, reset lại timer
- [ ] Không kích hoạt khi màn đã kết thúc (`ended == true`) hoặc đang `_animating`
- [ ] `flutter analyze` 0 lỗi

## Subtasks (gợi ý file)
- `lib/game/pop_star_game.dart` — thêm `Timer`/`TimerComponent` đếm ngược, reset trong `handleTap`; thêm hàm quét toàn bàn (lặp mọi ô chưa duyệt, gọi `findConnectedGroup`, giữ nhóm `length` lớn nhất) tái dùng `lib/logic/pop_detector.dart`.
- `lib/game/block_component.dart` (hoặc component overlay riêng) — thêm trạng thái/hiệu ứng highlight áp lên các ô thuộc nhóm gợi ý.
- Test: giả lập bàn tĩnh (không tap), advance timer qua `tester.pump`, assert có gọi highlight đúng nhóm lớn nhất kỳ vọng.

## Ghi chú kỹ thuật
Quét toàn bàn O(rows*cols) mỗi lần trigger (không phải mỗi frame) — đủ rẻ vì chỉ chạy sau 6s rảnh tay, không cần tối ưu incremental.

DoD chung: ../README.md.
