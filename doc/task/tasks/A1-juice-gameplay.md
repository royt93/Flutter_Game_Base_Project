# A1 — Juice gameplay (score popup + shake + squash)

**Epic:** Animation · **SP:** 5 · **Pri:** Must · **Deps:** F1 (popup hiện combo/điểm)

## Mục tiêu
Phản hồi "đã tay" tức thì khi nổ:
- **Score popup**: "+120" (x2 nếu combo) bay lên + mờ dần tại vị trí nổ.
- **Screen shake** nhẹ khi nổ nhóm lớn (cường độ theo cỡ nhóm).
- **Squash/stretch**: ô nảy nhẹ khi rơi settle (overshoot).

## Vì sao
Chuyển động là thứ nâng "chất cảm nhận" nhiều nhất — UI tĩnh trông rẻ dù màu đẹp.

## Acceptance criteria
- [ ] Nổ nhóm → text điểm nổi lên ~0.6s rồi biến mất, cỡ/màu theo combo.
- [ ] Nhóm lớn (≥ngưỡng) → bàn rung nhẹ (biên độ cap, tắt nhanh), không gây chóng mặt.
- [ ] Ô settle có overshoot nhẹ (đã có easeOutBack — tăng "nảy" có kiểm soát).
- [ ] Không chặn input lâu; 60fps trên device tầm trung.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: spawn `TextComponent` điểm tại tâm nhóm + MoveEffect
   lên + OpacityEffect/Remove; hàm `_shake(intensity)` (di chuyển camera/world nhẹ rồi về).
2. Squash: tinh chỉnh `MoveToEffect` + thêm `ScaleEffect` nhẹ khi settle.
3. Cường độ shake/popup theo `group.length` (và combo từ F1).
4. Cap hiệu ứng/frame để giữ perf.

## Ghi chú kỹ thuật
Shake bằng cách offset `camera`/`world` position rồi ease về 0 (Flame). Tiết chế:
ngưỡng shake ví dụ ≥5 ô; biên độ ≤ cellSize*0.15.

DoD chung: `../README.md`.
