---
id: BUG-15
title: "NeonBackButton default color hardcode hex, không dùng NeonTheme.cyan — không theo reskin/dark toggle"
type: bug
priority: P3
effort: S
source: Claude, audit round 3 (fork agent)
---

## Vị trí
`lib/presentation/widgets/neon_icon.dart` — `NeonBackButton`:
```dart
const NeonBackButton({
  super.key,
  this.color = const Color(0xFF00F0FF),
  this.onTap,
});
```

## Hiện trạng
Mọi widget "neon kit" khác định nghĩa màu mặc định qua `Color? color` +
`?? NeonTheme.xxx` trong `build()` (`NeonAppBar`, `AvatarFrame`,
`VictoryCardTemplate`, ...) — lý do đã ghi rõ trong comment của các file đó:
"a `NeonTheme` color field is no longer a compile-time constant" nên không
thể dùng làm default value `const` trực tiếp.

`NeonBackButton` là NGOẠI LỆ duy nhất: default value là hằng số
`const Color(0xFF00F0FF)` chép tay, khác hẳn `NeonTheme.cyan`
(`0xFF35C4F0`) — rõ ràng là màu cyan cũ từ trước đợt "candy" pivot
(comment đầu `neon_theme.dart` nói bảng màu đã đổi tông nhưng giữ tên
field cũ). `NeonTheme.cyan` còn nằm trong `importPalette()`
(`lib/core/neon_theme.dart` — case `'cyan': cyan = color;`), tức app có
thể reskin toàn bộ màu qua JSON — nhưng `NeonBackButton` dùng standalone
(không qua `NeonAppBar`) sẽ KHÔNG theo reskin đó vì giá trị bị đóng băng
compile-time.

Hiện tại điều này chưa lộ ra: `NeonAppBar` (nơi gọi `NeonBackButton` duy
nhất trong repo) luôn truyền `color` tường minh
(`NeonBackButton(color: color, onTap: onBack)`), nên default không bao giờ
được dùng trong code hiện có. Nhưng `NeonBackButton` là public widget
(exported qua `neon_icon.dart`, không phải qua barrel `common_widgets.dart`
nhưng vẫn import trực tiếp được) — consumer app tự dùng
`NeonBackButton()` không truyền `color` sẽ dính giá trị cứng, sai tông và
không theo reskin.

## Hậu quả
Thấp — chưa ai gặp phải (dead default trong repo này), nhưng là bẫy tiềm ẩn
cho consumer app dùng `NeonBackButton` độc lập, và không nhất quán với mọi
widget neon khác.

## Đề xuất fix
Đổi `Color color` → `Color? color`, resolve trong `build()`:
```dart
final color = this.color ?? NeonTheme.cyan;
```
(giống hệt pattern `NeonAppBar` đã dùng).

## Acceptance criteria
- [x] `NeonBackButton.color` là `Color?`, default `null`, resolve `?? NeonTheme.cyan` trong `build()`.
- [x] Test xác nhận không truyền `color` → dùng đúng `NeonTheme.cyan` hiện hành (không phải hex cũ).

## Quyết định
Đúng theo đề xuất: `color` → `Color?`, resolve `color ?? NeonTheme.cyan`
ngay tại điểm truyền vào `NeonIconButton`. TDD: viết
`test/widget/neon_back_button_test.dart` trước (2 case: không truyền color
→ `NeonTheme.cyan`, truyền color tuỳ chỉnh → giữ nguyên color đó), xác nhận
test đầu fail đúng lý do (`Actual: Color(0xFF00F0FF)` — hex cũ) trước khi
sửa production code. Verify: `flutter analyze`/`flutter test` sạch ở root
(428 pass, gồm 2 test mới) + `example/` (29 pass); `NeonAppBar` (nơi gọi
`NeonBackButton` duy nhất trong repo) verify live trên Samsung S24 Ultra
thật — render đúng, không đổi hành vi (vì luôn truyền `color` tường minh,
default trước giờ là dead code trong repo này, chỉ ảnh hưởng consumer app
tự dùng `NeonBackButton()` độc lập).
