# G1 — Glow pulse nhóm khi tap + điểm dự kiến

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Must · **Deps:** F1 (điểm dự kiến tính cả multiplier)

## Mục tiêu
Chạm-giữ (hoặc di ngón) trên 1 ô → cả nhóm cùng màu liền kề **sáng pulse** + hiện
**điểm sẽ ăn** (vd "+120") lơ lửng. Thả ra → nổ.

## Vì sao
Vừa juice (glow) vừa hỗ trợ chơi (thấy nhóm + điểm trước khi cam kết). Tăng tính
chủ động chiến thuật, đặc biệt hợp combo (F1).

## Acceptance criteria
- [ ] Chạm-giữ ô có nhóm ≥2 → mọi ô trong nhóm pulse glow (nhịp thở) + badge điểm dự kiến.
- [ ] Kéo ngón sang nhóm khác → highlight cập nhật theo nhóm mới.
- [ ] Thả trong nhóm hợp lệ → nổ nhóm đó; thả ngoài/nhóm size 1 → huỷ, không nổ.
- [ ] Tap nhanh (không giữ) vẫn nổ như cũ (không phá UX hiện tại).
- [ ] 60fps; glow tắt sạch khi thả.

## Subtasks (gợi ý file)
1. `lib/presentation/screens/game_screen.dart`: đổi `onTapUp` → `GestureDetector` với
   `onPanStart/onPanUpdate/onPanEnd` (hoặc long-press) truyền vị trí cho controller.
2. `lib/game/pop_star_game.dart`: `previewGroup(pos)` → set cờ highlight cho các
   BlockComponent trong nhóm (pulse `ScaleEffect`/glow), `clearPreview()`.
3. `block_component.dart`: trạng thái `highlighted` → vẽ glow mạnh + pulse.
4. Badge điểm dự kiến: TextComponent tại tâm nhóm = `scoreForGroup(n)*multiplier`.

## Ghi chú kỹ thuật
Giữ tap-nhanh hoạt động: nếu pan rất ngắn coi như tap. Preview không được đổi
`colorGrid` (chỉ hiển thị). Reset highlight chắc chắn ở `onPanEnd`/cancel.

DoD chung: `../README.md`.
