# A2 — Score count-up + progress bar target

**Epic:** Animation · **SP:** 3 · **Pri:** Must · **Deps:** —

## Mục tiêu
- Điểm HUD **nhảy dần** (tween) tới giá trị mới thay vì đổi tức thì.
- Thêm **thanh progress** dưới điểm: đầy dần theo `score/target`, đổi màu/nhấp nháy
  khi đạt/vượt target.

## Vì sao
Feedback tiến trình rõ ràng, chuẩn casual; người chơi thấy "sắp thắng".

## Acceptance criteria
- [ ] Điểm count-up mượt (~0.3s) mỗi lần cộng; không giật khi cộng liên tiếp.
- [ ] Progress bar phản ánh `score/target` (clamp ≤1), animate fill.
- [ ] Khi ≥target: bar đổi trạng thái "đạt" (màu + glow nhẹ) để báo có thể thắng.
- [ ] Không lỗi khi score nhảy lớn (bomb/rainbow).

## Subtasks (gợi ý file)
1. `lib/presentation/screens/game_screen.dart` `_Hud`: thay `StrokeText` điểm bằng
   widget count-up (TweenAnimationBuilder theo `gameCtrl.score.value`).
2. Thêm `LinearProgressIndicator` custom (bo tròn, gradient candy) đọc `score/target`.
3. Trạng thái đạt target: đổi màu bar + nhẹ glow.

## Ghi chú kỹ thuật
`TweenAnimationBuilder<double>` với key theo giá trị đích → tự animate khi đổi.
Progress bar tự vẽ `Container` bo tròn + `FractionallySizedBox` cho gọn.

DoD chung: `../README.md`.
