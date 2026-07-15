# A3 — Route transition + button bounce

**Epic:** Animation · **SP:** 3 · **Pri:** Should · **Deps:** —

## Mục tiêu
- Chuyển màn (Home↔LevelSelect↔Game↔Shop…) có transition slide/scale + fade.
- Nút bấm (NeonButton, chip, icon) có micro-bounce khi nhấn (scale 0.94 → về).

## Vì sao
Polish tổng thể mượt, "cao cấp"; tránh cắt cảnh cứng.

## Acceptance criteria
- [x] Điều hướng dùng transition nhất quán (GetX `defaultTransition` hoặc custom).
- [x] Mọi nút chính phản hồi nhấn bằng bounce (không delay cảm nhận).
- [x] Không phá `PopScope`/back button hiện có ở Game.
- [ ] Không rớt frame lúc chuyển. (chưa chạy tay trên device, chỉ verify code + test tự động)

## Rà soát checkbox (2026-07-13)
- `lib/main.dart`: `GetMaterialApp` có `defaultTransition: Transition.cupertino` + `transitionDuration: Duration(milliseconds: 280)`.
- `PressableScale` (`lib/presentation/widgets/pressable_scale.dart`, có test `test/widget/pressable_scale_test.dart`) được dùng trong `neon_button.dart`, `neon_icon.dart`, `neon_dialog.dart`, `shop_screen.dart`, `season_screen.dart`, `star_road_screen.dart`, `game_screen.dart`.
- Grep `PopScope` trong `lib/presentation/screens/game_screen.dart`: vẫn còn nguyên (dòng 34).

## Subtasks (gợi ý file)
1. `lib/main.dart`: đặt `GetMaterialApp.defaultTransition` + `transitionDuration`.
2. `lib/presentation/widgets/neon_button.dart` + `neon_icon.dart` + `coin_chip.dart`:
   bọc `GestureDetector` bằng scale-on-tap (dùng `StatefulWidget` nhỏ hoặc
   `AnimatedScale` theo trạng thái nhấn).
3. Kiểm Game vẫn intercept back đúng (không đổi route bằng transition gây kẹt).

## Ghi chú kỹ thuật
Tạo 1 wrapper `PressableScale` tái dùng cho mọi nút → 1 chỗ, đỡ lặp. GetX transition:
`Transition.cupertino`/`fadeIn`/custom.

DoD chung: `../README.md`.
