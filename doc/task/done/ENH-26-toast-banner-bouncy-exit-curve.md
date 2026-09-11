---
id: ENH-26
title: "ToastBanner dùng chung 1 curve bouncy (easeOutBack) cho cả entrance lẫn exit, khác quy ước NeonDialog"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork B)
---

## Vị trí
`lib/presentation/widgets/common/toast_banner.dart` — `ToastBanner.show()`:
```dart
final slide = Tween<Offset>(
  begin: const Offset(0, -0.3),
  end: Offset.zero,
).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));
```
`controller.reverse()` dùng lại animation này khi remove().

## Hiện trạng
`CurvedAnimation` chỉ truyền `curve:`, không truyền `reverseCurve:` — Flutter
mặc định dùng CÙNG curve cho chiều reverse (chỉ lật input, không đổi hàm).
`Curves.easeOutBack` có overshoot RÕ RỆT ở cuối đường cong — khi dùng cho
reverse (lúc `remove()` gọi `controller.reverse()`), overshoot đó rơi vào
NGAY LÚC BẮT ĐẦU đóng, tức toast sẽ hơi "giật/nảy ngược" một nhịp trước khi
trượt lên biến mất, thay vì đóng êm.

So sánh với `neon_dialog.dart`'s `NeonDialog.show()`:
```dart
transitionBuilder: (context, animation, secondary, child) => FadeTransition(
  opacity: animation,
  child: ScaleTransition(
    scale: CurvedAnimation(
      parent: animation,
      curve: _kDialogCurve, // easeOutBack
      reverseCurve: Curves.easeIn, // <-- exit dùng curve khác, êm hơn
    ),
    ...
```
`NeonDialog` đã đúng quy ước "vào bouncy, ra êm" — `ToastBanner` là chỗ
DUY NHẤT trong nhóm overlay/feedback bỏ sót `reverseCurve`.

## Vì sao cần
Không phải bug chức năng (toast vẫn đóng đúng, không throw), nhưng là 1
tiểu tiết animation "kém xịn" đúng như hướng người dùng muốn cải thiện —
motion không nhất quán với dialog pattern đã chuẩn hoá trong repo.

## Đề xuất
Thêm `reverseCurve: Curves.easeIn` (khớp `_kDialogCurve`/`Curves.easeIn`
pattern của `neon_dialog.dart`) vào `CurvedAnimation` của `slide`.

## Acceptance criteria
- [x] `ToastBanner`'s `CurvedAnimation` có `reverseCurve` riêng (không bouncy) cho chiều đóng.
- [x] Test xác nhận `reverseCurve` được set đúng (hoặc test hành vi: giá trị animation không vượt quá [0,1] theo hướng ngược trong vài frame đầu của `reverse()`).

## Quyết định
Thêm đúng `reverseCurve: Curves.easeIn` như đề xuất. Test theo hướng hành
vi (không đọc trực tiếp field vì `slide` là biến cục bộ trong static
method, không expose ra ngoài): dựng toast thật, băng qua mốc `duration`
bằng đúng timing pattern đã proven ổn định ở test khác trong file (pump
300ms rồi 250ms), sau đó pump thêm 20ms để ticker của `reverse()` (vừa
được kích hoạt bởi timer) có thời gian chạy, rồi đọc trực tiếp
`SlideTransition.position.value.dy` — xác nhận fail đúng lý do trước khi
sửa (đo được dy tăng dần tới ~0.026, chứng minh overshoot ngược có thật),
pass sau khi thêm `reverseCurve`. Verify: `flutter analyze` sạch +
`flutter test` 461 pass ở root (457+4, gộp chung ENH-26+27), 29 pass ở
`example/`. Device smoke Pixel 7 Pro thật: bấm Show toast, toast hiện
đúng, không exception.
