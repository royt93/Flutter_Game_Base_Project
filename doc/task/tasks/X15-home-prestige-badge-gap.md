# X15 — Bổ sung badge Prestige còn thiếu ở HomeScreen

**Epic:** bugfix · **SP:** 1 · **Pri:** Should · **Deps:** [[I27]]

## Mục tiêu
Đóng gap được xác nhận qua 2 vòng audit độc lập cho I27 (Prestige/New Game+):
spec I27 yêu cầu entry-point/badge prestige xuất hiện ở cả `HomeScreen` lẫn
`LevelSelectScreen`, nhưng badge chỉ tồn tại ở `LevelSelectScreen` (dưới dạng
widget private `_PrestigeAction`) — `HomeScreen` hoàn toàn không có, grep
`PrestigeAction`/`prestige` trong `home_screen.dart` trả về rỗng.

## Vì sao
Khi implement I27, `_PrestigeAction` + `_showPrestigeDialog` được viết thẳng
là private trong `level_select_screen.dart` nên không thể tái sử dụng ở
`home_screen.dart` mà không copy-paste code. Việc này lọt qua vì
`prestige_action_test.dart` chỉ test qua `LevelSelectScreen`.

## Đã sửa
Extract sang widget dùng chung thay vì copy-paste (DRY):
- File mới `lib/presentation/widgets/prestige_action.dart` — public
  `showPrestigeDialog(context, gameCtrl)` (free function) + public class
  `PrestigeAction` (widget badge), chuyển nguyên logic từ bản private cũ.
- `level_select_screen.dart` — xoá `_PrestigeAction`/`_showPrestigeDialog`
  private, import và dùng bản dùng chung.
- `home_screen.dart` — thêm `PrestigeAction(gameCtrl: gameCtrl, onTap: () =>
  showPrestigeDialog(context, gameCtrl))` vào Row app-bar trên cùng, cạnh
  `CoinChip`.

## Acceptance criteria
- [x] `PrestigeAction` hiển thị ở cả `HomeScreen` và `LevelSelectScreen`
      với cùng logic ẩn/hiện/tap (`Key('prestige_badge')`).
- [x] `flutter analyze` 0 issues.
- [x] `flutter test --exclude-tags slow` xanh toàn bộ (không regression từ
      refactor `level_select_screen.dart`).

## Ghi chú kỹ thuật
`prestige_action_test.dart` không cần sửa vì chỉ test qua
`LevelSelectScreen`, không construct trực tiếp widget cũ. Không tạo test
file mới riêng cho `HomeScreen` badge — coverage hiện có qua
`home_screen_test.dart` (smoke) đã đủ vì logic hiển thị/tap đã được cover ở
`prestige_action_test.dart` dùng chung.

DoD chung: `../README.md`.
