---
id: ENH-17
title: "14 widget có animation thật nhưng chưa check NeonTheme.reducedMotion"
type: enhance
priority: P2
effort: M
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Hiện trạng
Grep xác nhận các widget sau có animation (Ticker/AnimationController/
TweenAnimationBuilder) nhưng KHÔNG check `NeonTheme.reducedMotion(context)`:
`circular_progress_ring`, `coin_fly_overlay`, `confetti_overlay`,
`floating_combo_text`, `network_status_banner`, `paginated_dots_indicator`,
`progress_bar_stars`, `reward_popup`, `shimmer_placeholder`, `toast_banner`,
`toggle_switch`, `flame_tracked_overlay`, `neon_bg`, `neon_dialog`.
(`shader_ticker_layer.dart` đã đúng — không tính vào danh sách này.)

## Vì sao cần
`reducedMotion` là accessibility helper trung tâm của package (đã áp dụng
cho `PressableScale`, `StarRating`, `CurrencyCounter`, `SquashStretch`,
`ScreenShake`, `ComboHeatBackground`...) — thiếu ở 14 chỗ này là thiếu sót
nhất quán, không phải lỗi nghiêm trọng.

## Đề xuất phạm vi
Không phải mọi widget trong danh sách đều CẦN sửa như nhau — phân loại trước
khi làm:
- Thuần trang trí (nên sửa): `confetti_overlay`, `floating_combo_text`,
  `coin_fly_overlay`, `reward_popup`, `neon_bg` (particle nền).
- Feedback chức năng (cân nhắc, có thể không cần): `shimmer_placeholder`,
  `toast_banner`, `network_status_banner` — animation ở đây mang thông tin
  trạng thái, tắt hẳn có thể làm mất feedback quan trọng, không chỉ là
  "trang trí".
- Còn lại: xem từng case cụ thể trước khi quyết định.

## Acceptance criteria
- [x] Từng widget trong danh sách "nên sửa": Duration → `Duration.zero` khi
      `reducedMotion` bật (đúng pattern `CurrencyCounter`/`ComboHeatBackground`
      đã dùng), hoặc tắt hẳn animation nếu là particle/ticker liên tục.
- [x] Test riêng cho mỗi widget vừa sửa xác nhận hành vi dưới `reducedMotion`.

## Quyết định
Sửa 13/14 widget trong danh sách: `circular_progress_ring`,
`coin_fly_overlay`, `confetti_overlay`, `floating_combo_text`,
`network_status_banner`, `paginated_dots_indicator`, `progress_bar_stars`,
`reward_popup`, `shimmer_placeholder`, `toast_banner`, `toggle_switch`,
`neon_bg`, `neon_dialog`. Loại `flame_tracked_overlay` khỏi phạm vi — motion
ở đó gắn với vị trí thật của component Flame (chức năng, không phải trang
trí), tắt animation sẽ làm overlay lệch khỏi world position.

`StatefulWidget` tạo controller/ticker trong `initState()` chuyển sang
`didChangeDependencies()` (MediaQuery không đọc được sớm hơn); static
method không có context riêng (`NeonDialog.overlay`/`overlaySlot`) bọc phần
animated trong `Builder` để lấy context. Nhân tiện sửa luôn 1 bug thật ở
`RewardPopup`: field `_burst` là `late final` lazy-init, chỉ được tạo (và
dispose đúng) khi từng bị truy cập — nay luôn được tạo ở
`didChangeDependencies()`.

Verify: `flutter analyze` sạch + `flutter test --exclude-tags slow` 422 pass
ở root, sạch + 29 pass ở `example/`. Test trực tiếp trên Pixel 7 Pro thật
(`2B051FDH3006MU`, S24U lúc đó không kết nối được) qua `flutter run`: mở
Widget Kit, kích hoạt `ToastBanner`, `PaginatedDotsIndicator`,
`LevelSelectGrid` (regression check ENH cũ), `RewardPopup` (dialog + confetti
burst) — không exception, không overflow trong toàn bộ live log.
