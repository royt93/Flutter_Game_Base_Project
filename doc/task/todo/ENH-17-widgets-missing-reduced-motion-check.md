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
- [ ] Từng widget trong danh sách "nên sửa": Duration → `Duration.zero` khi
      `reducedMotion` bật (đúng pattern `CurrencyCounter`/`ComboHeatBackground`
      đã dùng), hoặc tắt hẳn animation nếu là particle/ticker liên tục.
- [ ] Test riêng cho mỗi widget vừa sửa xác nhận hành vi dưới `reducedMotion`.
