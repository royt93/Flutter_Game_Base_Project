# X9 — Redesign Home Screen: Drawer + banner ưu tiên đơn

**Epic:** UX baseline · **SP:** 5 · **Pri:** Should · **Deps:** —

## Mục tiêu
Home Screen cũ xếp 13 `NeonIconButton` giống nhau thành 4 hàng, không label,
không phân nhóm, không hệ thống thứ bậc — user chê "quá xấu, thiết kế quá
tệ". Redesign theo hướng **Drawer + banner ưu tiên đơn** (đã chốt qua 2 vòng
`AskUserQuestion`):
- Header: hamburger mở `Scaffold.endDrawer` + coin chip.
- 1 banner ưu tiên cao nhất duy nhất (không carousel): weekend event >
  Season Pass milestone sẵn sàng nhận > Daily Challenge chưa chơi hôm nay >
  ẩn hẳn.
- Quick-access row rút về đúng 3 icon: Shop, Daily Challenge, Modes (dialog
  chọn Time Attack/Zen/Endless).
- 8 mục còn lại (Star Road, Spin Wheel, Guide, Settings, Leaderboard, Season
  Pass, Perks, Achievements) dồn vào `endDrawer` dạng `ListTile` có label,
  chia 2 nhóm "Khám phá"/"Tài khoản".

## Vì sao
13 icon tròn không label buộc người chơi phải nhớ vị trí/hình dạng để đoán
chức năng; không có phân cấp ưu tiên nên mọi tính năng (kể cả ít dùng) chiếm
diện tích ngang với PLAY. Drawer là pattern Flutter chuẩn, không bị giới hạn
overlay như `GameScreen` (không dùng Flame `GameWidget`) nên dùng được
`Scaffold.endDrawer` trực tiếp.

## Acceptance criteria
- [x] Header có hamburger mở Drawer + coin chip, không còn 13-icon-4-hàng cũ.
- [x] Banner ưu tiên đơn đúng thứ tự weekend > season pass ready > daily
      challenge reminder > ẩn; tap đúng đích (Season Pass screen / start
      Daily Challenge → GameScreen).
- [x] Quick-access row đúng 3 icon: Shop, Daily Challenge, Modes.
- [x] Drawer có đủ 8 mục, đúng icon/màu/nav như code cũ, đóng drawer trước
      khi điều hướng.
- [x] 3 key i18n mới (`modes_title`, `season_pass_banner_ready`,
      `daily_challenge_banner_reminder`) đủ 22 locale.
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.
- [x] Playtest tay trên device thật (Samsung SM_S928B, `R5CX613VZBR`):
      hamburger → Drawer → từng mục trong 8 mục đều mở đúng màn (Star Road,
      Spin Wheel, Guide, Settings, Leaderboard, Season Pass, Perks,
      Achievements); Shop icon; Modes dialog → Time Attack vào được
      GameScreen; banner Daily Challenge tap đúng vào GameScreen chế độ
      Daily Challenge. Không gặp quảng cáo che UI ở bất kỳ bước nào.

## Ghi chú kỹ thuật
- Banner bọc `Obx` vì season dùng `seasonPoints`/`claimedSeasonMask` (Rx) —
  tự cập nhật khi quay lại Home mà không cần rebuild toàn màn.
- Không thêm `StorageKeys` mới — banner dùng đúng state Rx đã có sẵn
  (`seasonPoints`, `claimedSeasonMask`, `canRecordDailyChallengeScore`,
  `isWeekendEvent`). Bỏ qua "banner dismissal tracking" — để dành nếu cần
  sau.
- Dialog Modes (3 nút Time Attack/Zen/Endless) giữ **y hệt code cũ**
  (`Get.to(() => const GameScreen())` không dismiss dialog trước) theo đúng
  yêu cầu tái sử dụng nguyên vẹn — xem bug phát hiện dưới đây.

## Bug phát hiện trong lúc playtest — ĐÃ FIX (2026-07-17)
Sau khi vào level từ dialog Modes (vd Time Attack) rồi thoát màn, dialog
Modes cũ bị lộ lại đè lên Home thay vì Home sạch. Root cause: `NeonDialog.show`
dùng `Navigator.of(context, rootNavigator: true)` + `showDialog` native —
chia sẻ đúng root navigator với `Get.to()` của GetX. Các nút trong `content`
của dialog Modes (Time Attack/Zen/Endless) nằm ngoài cơ chế tự `pop` của
`actions` (`NeonDialog.show` chỉ tự bọc pop-trước-rồi-chạy-onTap cho các
`NeonDialogAction` trong `actions:`, không áp dụng cho widget tuỳ ý trong
`content:`), nên gọi `Get.to(() => const GameScreen())` mà không
`Navigator.pop(context)` dialog trước — stack thành
`[Home, DialogRoute, GameScreenRoute]`; thoát GameScreen chỉ pop 1 route, lộ
lại DialogRoute còn nằm dưới. Fix: thêm `Navigator.pop(context);` đầu mỗi
`onTap` của 3 nút trong `_showModesDialog` (`home_screen.dart`), trước khi
gọi `startSideMode`/`startEndless` + `Get.to`. Đã playtest lại trên device
thật (Samsung SM_S928B): Modes → Time Attack → GameScreen → Thoát Màn → Home
sạch, không còn dialog lộ lại.

DoD chung: `../README.md`.
