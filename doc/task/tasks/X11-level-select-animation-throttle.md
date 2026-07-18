# X11 — Throttle animation repaint trên Level Select (audit hiệu suất)

**Epic:** performance · **SP:** 1 · **Pri:** Should · **Deps:** none

## Mục tiêu
User phản ánh hiệu suất game "tệ/lag". Audit lại các task cũ + quét trực
tiếp code để tìm nguyên nhân, tập trung vào những chỗ chạy animation liên
tục (continuous `AnimationController`) vì đây là nguồn giật/lag phổ biến
nhất trên máy tầm trung.

## Vì sao
`level_select_screen.dart` có `_flowCtrl` — một `AnimationController` lặp
tuyến tính 2 giây, chạy ở ~60fps liên tục miễn màn hình đang mở, kể cả khi
không có tương tác gì. Hai `AnimatedBuilder` (decor sparkle painter, path
glow painter) đều listen thẳng vào `_flowCtrl`, khiến `CustomPaint` vẽ lại
toàn bộ canvas (tới ~1000+ dot trang trí + 219 đoạn path) mỗi frame — dù
giá trị chỉ đổi rất nhỏ giữa 2 frame liên tiếp. Đây là lãng phí CPU/GPU rõ
rệt, đúng loại vấn đề gây lag mà user đang chê.

## Đã sửa
Thêm getter throttle, tận dụng `shouldRepaint` đã so sánh giá trị sẵn có:
```dart
double get _throttledFlow => (_flowCtrl.value * 60).floorToDouble() / 60;
```
Đổi cả 2 call site (`_DecorPainter`, `_PathPainter`) dùng `_throttledFlow`
thay vì `_flowCtrl.value` trực tiếp — làm tròn giá trị animation xuống mốc
1/60 giây, giảm khoảng một nửa số lần `shouldRepaint` trả `true` mà không
đổi hành vi animation nhìn thấy được (mượt mà vẫn giữ nguyên, vì bước làm
tròn nhỏ hơn ngưỡng mắt người nhận ra). Cùng pattern throttle đã dùng ở
`neon_bg.dart` (`_onTick`/`_skipFrame`, repaint mỗi tick thứ 2).

## Điều tra thêm nhưng KHÔNG sửa (rủi ro thấp, không phải nguyên nhân chính)
- `pop_star_game.dart` `_clearAndCollapse`: particle burst đã cap từ G9,
  `_rings` đã cap `_maxRings = 3` — không có cap cho tổng số
  `ParticleSystemComponent` sống cùng lúc qua nhiều lần tap liên tiếp rất
  nhanh, nhưng game này không có auto-cascade nên xác suất user tap đủ
  nhanh để tích luỹ instance là thấp. Để lại quan sát, không fix phòng hờ.
- `block_component.dart`: bloom/heat blur anti-pattern chính đã fix từ
  trước; `highlighted`/`hinted` vẫn dùng `MaskFilter.blur` mỗi frame nhưng
  chỉ ảnh hưởng số ô nhỏ (hint/highlight, không phải toàn bàn) — tác động
  không đáng kể so với chi phí thay đổi.

## Acceptance criteria
- [x] `_throttledFlow` thêm vào `level_select_screen.dart`, cả 2 painter
      dùng giá trị throttle thay vì raw `_flowCtrl.value`.
- [x] Animation vẫn mượt mắt thường (không giật, không đứng hình) khi xem
      trực tiếp trên device.
- [x] `flutter analyze` 0 issues.
- [x] `flutter test --exclude-tags slow` xanh toàn bộ (261 test).

## Ghi chú kỹ thuật
Không phải mọi lag user cảm nhận đều đo được qua test tự động (frame time
không nằm trong phạm vi widget test) — verify chủ yếu qua đọc code +
device thật, không có test riêng cho throttle này (thay đổi thuần
performance, không đổi hành vi để assert).

DoD chung: `../README.md`.
