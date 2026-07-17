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
- [x] Nổ nhóm → text điểm nổi lên ~0.6s rồi biến mất, cỡ/màu theo combo.
- [x] Nhóm lớn (≥ngưỡng) → bàn rung nhẹ (biên độ cap, tắt nhanh), không gây chóng mặt. — `_maybeTriggerShake` (`pop_star_game.dart`): nhóm ≥5 ô → mọi block còn lại nhận `SequenceEffect` 3 nhịp `MoveByEffect` qua-lại-về (biên độ `cellSize*0.12`, tổng ~0.12s), không đụng ô vừa nổ. Camera thật không dùng được (board add trực tiếp vào game, không qua `camera.world` — như A7 đã ghi chú) nên rung bằng offset vị trí block thay vì camera (2026-07-14).
- [x] Ô settle có overshoot nhẹ (đã có easeOutBack — tăng "nảy" có kiểm soát).
- [x] Không chặn input lâu; 60fps trên device tầm trung. Verify tay trên Samsung SM_S928B (2026-07-17): chơi Level 1 hết bàn, `_animating` không kẹt lần nào, `adb logcat -d | grep -i "Choreographer\|skipped\|FATAL"` không có match trong suốt phiên tap liên tục.

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

## Rà soát checkbox (2026-07-13)
- Grep `_spawnScorePopup` trong `lib/game/pop_star_game.dart`: text "+N  xM" bay lên bằng `MoveByEffect` (0.6s) + `ScaleEffect` easeOutBack, cỡ/màu theo combo — khớp dòng 15.
- Grep `easeOutBack` trong `_collapseAnimated`: `MoveToEffect(..., EffectController(duration: _fallDur, curve: Curves.easeOutBack))` — khớp dòng 17.
- Grep `shake`/`Shake`/`_shake` toàn `lib/game/` và `lib/presentation/screens/`: không có match — không tìm thấy cơ chế rung bàn (`_maybeTriggerPunch` A7 chỉ zoom-punch + slow-mo, không di chuyển camera/world để shake) — dòng 16 để ngỏ.
